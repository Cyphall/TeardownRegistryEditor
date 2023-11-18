UiTextBox = {}

function UiTextBox:new(width)
	local instance = {}
	setmetatable(instance, self)
	self.__index = self

	-- contains the text of the textbox
	self._text = ""

	-- wether this text box has focus
	self._has_focus = false

	-- table to convert keys to lowercase or uppercase characters
	self._keys = {
		{"a", "a", "A"},
		{"b", "b", "B"},
		{"c", "c", "C"},
		{"d", "d", "D"},
		{"e", "e", "E"},
		{"f", "f", "F"},
		{"g", "g", "G"},
		{"h", "h", "H"},
		{"i", "i", "I"},
		{"j", "j", "J"},
		{"k", "k", "K"},
		{"l", "l", "L"},
		{"m", "m", "M"},
		{"n", "n", "N"},
		{"o", "o", "O"},
		{"p", "p", "P"},
		{"q", "q", "Q"},
		{"r", "r", "R"},
		{"s", "s", "S"},
		{"t", "t", "T"},
		{"u", "u", "U"},
		{"v", "v", "V"},
		{"w", "w", "W"},
		{"x", "x", "X"},
		{"y", "y", "Y"},
		{"z", "z", "Z"},
		{"0", "0", "0"},
		{"1", "1", "1"},
		{"2", "2", "2"},
		{"3", "3", "3"},
		{"4", "4", "4"},
		{"5", "5", "5"},
		{"6", "6", "6"},
		{"7", "7", "7"},
		{"8", "8", "8"},
		{"9", "9", "9"},
		{"space", " ", " "},
		{"f1", ".", "."},
		{"f2", "-", "-"},
		{"f3", "/", "/"}
	}

	-- width of the text box
	self._width = width

	-- used to calculate the text box height & blinking cursor height
	self._text_height = 0

	-- used to draw the text box background
	self._height = 0

	-- offset used to render the text at the right position
	self._baseline_offset = 0

	-- used for two hacks bellow
	self._o_character_width = 0

	-- for some reason, UiGetTextSize() returns the width as if the text had some headroom on the left
	-- e.g. with "regular.ttf" at font size 20, UiGetTextSize("o") will return 16 and UiGetTextSize("oo") will return 24.
	-- here the offset will be 8.
	-- also, when rendering text from the "left" align, it seems that the first character is offset by half this ammount (that's the value that is stored in self._offset_in_text_size)
	self._offset_in_text_size = 0

	-- "blinking cursor" position
	self._cursor_pos = 0

	-- used to actually blink the cursor
	self._cursor_blink_rate = 0.53
	self._cursor_blink_visible = false
	self._next_cursor_blink = 0

	-- this hack is needed to unfocus the text box when it is no longer visible
	self._was_rendered_last_frame = true

	-- used to offset the text & cursor draw position if it does not fit in the text box
	self._draw_offset = 0

	-- used as content padding
	self._padding = 2

	-- stores the blinking cursor width
	self._cursor_width = 2

	return instance
end

function UiTextBox:_get_advance_forward()
	local count = 0
	if InputDown("ctrl") then
		for i=1+self._cursor_pos+1, string.len(self._text) + 1 do
			count = count + 1
			if string.sub(self._text, i-1, i-1) == " " and string.sub(self._text, i, i) ~= " " then
				break
			end
		end
	elseif self._cursor_pos < string.len(self._text) then
		count = 1
	end
	return count
end

function UiTextBox:_get_advance_backward()
	local count = 0
	if InputDown("ctrl") then
		for i=1+self._cursor_pos-1, 1, -1 do
			count = count + 1
			if string.sub(self._text, i-1, i-1) == " " and string.sub(self._text, i, i) ~= " " then
				break
			end
		end
	elseif self._cursor_pos > 0 then
		count = 1
	end
	return count
end

function UiTextBox:_calc_text_size(text)
	local text_width
	if text ~= "" then
		-- hack to corrently handle text size if the trailing characters are spaces (UiGetTextSize behaves weirdly in this case)
		text_width, _ = UiGetTextSize(text .. "o")
		text_width = text_width - self._o_character_width

		-- hack to remove leading padding added by UiGetTextSize
		text_width = text_width - self._offset_in_text_size
	else
		text_width = 0
	end
	return text_width
end

function UiTextBox:tick(delta_time)
	submit_pressed = false

	if not self._was_rendered_last_frame then
		self._has_focus = false
	end
	self._was_rendered_last_frame = false

	if self._has_focus then
		local text_or_cursor_changed = false

		local character_to_add

		if not InputDown("ctrl") then
			for i = 1, #self._keys do
				if InputPressed(self._keys[i][1]) then
					local shift = InputDown("shift")

					if shift == true then
						character_to_add = self._keys[i][3]
					elseif shift == false then
						character_to_add = self._keys[i][2]
					end
				end
			end
		end

		if character_to_add then
			self._text = string.sub(self._text, 1, self._cursor_pos) .. character_to_add .. string.sub(self._text, self._cursor_pos + 1, -1)
			self._cursor_pos = self._cursor_pos + 1
			text_or_cursor_changed = true
		end

		if InputPressed("backspace") then
			local delete_count = self:_get_advance_backward()
			self._text = string.sub(self._text, 1, self._cursor_pos - delete_count) .. string.sub(self._text, self._cursor_pos + 1, -1)
			self._cursor_pos = self._cursor_pos - delete_count
			text_or_cursor_changed = true
		end

		if InputPressed("delete") then
			local delete_count = self:_get_advance_forward()
			self._text = string.sub(self._text, 1, self._cursor_pos) .. string.sub(self._text, self._cursor_pos + 1 + delete_count, -1)
			text_or_cursor_changed = true
		end

		self._next_cursor_blink = self._next_cursor_blink - delta_time
		if self._next_cursor_blink < 0 then
			self._next_cursor_blink = self._next_cursor_blink + self._cursor_blink_rate
			self._cursor_blink_visible = not self._cursor_blink_visible
		end

		if InputPressed("rightarrow") then
			local move_count = self:_get_advance_forward()
			self._cursor_pos = self._cursor_pos + move_count
			text_or_cursor_changed = true
		end

		if InputPressed("leftarrow") then
			local move_count = self:_get_advance_backward()
			self._cursor_pos = self._cursor_pos - move_count
			text_or_cursor_changed = true
		end

		if text_or_cursor_changed then
			self._next_cursor_blink = self._cursor_blink_rate
			self._cursor_blink_visible = true
		end

		if InputPressed("return") then
			submit_pressed = true
		end
	else
		self._cursor_blink_visible = false
	end

	return submit_pressed
end

function UiTextBox:draw()
	self._was_rendered_last_frame = true

	UiPush()

	if self._text_height == 0 then
		local _, scaled_font_height = UiGetTextSize("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
		local _, scaled_baseline_height = UiGetTextSize("A")

		self._text_height = UiFontHeight()
		self._baseline_offset = self._text_height * scaled_baseline_height / scaled_font_height
		self._height = self._text_height + self._padding * 2

		local width1, _ = UiGetTextSize("o")
		local width2, _ = UiGetTextSize("oo")
		self._o_character_width = width2 - width1
		self._offset_in_text_size = (width1 - self._o_character_width) / 2
	end

	UiWindow(self._width, self._height, true)

	local text_width = self:_calc_text_size(self._text)
	local text_width_before_cursor = self:_calc_text_size(string.sub(self._text, 1, self._cursor_pos))

	UiPush()

	UiColor(0, 0, 0, 0.5)
	UiAlign("top left")
	UiRect(self._width, self._height)

	UiPop()

	UiTranslate(self._padding, self._padding)

	local content_width = self._width - self._padding * 2

	local cursor_left_pos_from_box = text_width_before_cursor - self._draw_offset
	if cursor_left_pos_from_box < 0 then
		local left_overdraw = -cursor_left_pos_from_box
		self._draw_offset = self._draw_offset - left_overdraw
	end

	local cursor_right_pos_from_box = cursor_left_pos_from_box + self._cursor_width
	if cursor_right_pos_from_box > content_width then
		local right_overdraw = cursor_right_pos_from_box - content_width
		self._draw_offset = self._draw_offset + right_overdraw
	end

	local text_right_end_from_box = (text_width + self._cursor_width) - self._draw_offset
	if self._draw_offset > 0 and text_right_end_from_box < content_width then
		local right_underdraw = content_width - text_right_end_from_box
		self._draw_offset = math.max(self._draw_offset - right_underdraw, 0)
	end

	UiTranslate(-self._draw_offset, 0)

	-- this logic need to be in tick since we need to know the text box screen location to check if the mouse is over it
	if UiReceivesInput() and InputPressed("lmb") then
		if UiIsMouseInRect(self._width, self._height) then
			self._has_focus = true
			self._next_cursor_blink = self._cursor_blink_rate
			self._cursor_blink_visible = true
		else
			self._has_focus = false
		end
	end

	UiPush()

	UiTranslate(0, self._baseline_offset)

	UiColor(1, 1, 1, 1)
	UiAlign("left")
	UiText(self._text)

	UiPop()

	if self._cursor_blink_visible then
		UiPush()

		UiTranslate(text_width_before_cursor, 0)

		UiColor(1, 1, 1, 1)
		UiAlign("top left")
		UiRect(self._cursor_width, self._text_height)

		UiPop()
	end

	UiPop()
end

function UiTextBox:get_text()
	return self._text
end

function UiTextBox:set_text(text)
	self._text = text
	self._cursor_pos = 0
end

function UiTextBox:has_focus()
	return self._has_focus
end

function UiTextBox:set_focus(has_focus)
	self._has_focus = has_focus
end

function UiTextBox:get_width()
	return self._width
end

function UiTextBox:get_height()
	return self._height
end