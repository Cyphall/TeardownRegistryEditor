#include "UiTextBox.lua"

function clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function sign(value)
	if value < 0 then
		return -1
	elseif value > 0 then
		return 1
	else
		return 0
	end
end

function init()
	explorer_enabled = false

	title_height = 30
	grid_header_height = 26
	grid_row_height = 24

	children_offset = 16

	last_max_key_width   = 0
	last_max_value_width = 0
	last_drawn_row_count = 0
	last_grid_visual_height = 0

	current_max_key_width   = 0
	current_max_value_width = 0
	current_drawn_row_count = 0
	current_grid_visual_height = 0

	open_nodes = {}

	scroll_current_position = 0
	scroll_target_position = 0

	edit_value_text_box = nil
	currently_edited_node = nil
	submit_pressed = false
end

function tick(delta_time)
	if (not edit_value_text_box or edit_value_text_box and not edit_value_text_box:has_focus()) and InputPressed("f10") then
		explorer_enabled = not explorer_enabled
	end

	local grid_rows_total_height = last_drawn_row_count * grid_row_height

	local max_scroll_position = math.max(grid_rows_total_height - last_grid_visual_height, 0)
	scroll_target_position = clamp(scroll_target_position - InputValue("mousewheel") * grid_row_height * 3, 0, max_scroll_position)

	-- smooth scrolling
	local scroll_current_to_target_distance = math.abs(scroll_target_position - scroll_current_position)
	local scroll_current_to_target_direction = sign(scroll_target_position - scroll_current_position)
	scroll_current_position = scroll_current_position + math.min((scroll_current_to_target_distance + 2) * 15 * delta_time, scroll_current_to_target_distance) * scroll_current_to_target_direction

	if edit_value_text_box then
		submit_pressed = edit_value_text_box:tick(delta_time)
	end
end

function draw()
	if explorer_enabled then
		UiMakeInteractive()

		draw_window()
	end
end

function draw_window()
	UiPush()
		last_max_key_width = math.max(current_max_key_width, 200)
		current_max_key_width = 0
		last_max_value_width = clamp(current_max_value_width, 200, UiWidth() - 50 - 1 - last_max_key_width - 1 - 1 - 50)
		current_max_value_width = 0
		last_drawn_row_count = current_drawn_row_count
		current_drawn_row_count = 0
		last_grid_visual_height = current_grid_visual_height
		current_grid_visual_height = 0

		available_size = {
			x = last_max_key_width + last_max_value_width + 100 + 3,
			y = UiHeight()
		}

		draw_background(available_size)

		draw_title(available_size)

		-- small padding between title and grid
		UiTranslate(0, 5)
		available_size.y = available_size.y - 5

		draw_grid(available_size)
	UiPop()
end

function draw_background(available_size)
	UiPush()
		UiColor(0.15, 0.15, 0.15, 0.95)
		UiImageBox("ui/window_background.png", available_size.x, available_size.y, 50, 50)
	UiPop()

	UiTranslate(50, 50)
	UiWindow(available_size.x - 100, available_size.y - 100, true, true)

	available_size.x = available_size.x - 100
	available_size.y = available_size.y - 100
end

function draw_title(available_size)
	UiPush()
		UiAlign("left top")
		UiFont("regular.ttf", title_height)
		UiColor(0.95, 0.95, 0.95)
		UiTextUniformHeight(true)

		UiText("Registry Editor")
	UiPop()

	UiTranslate(0, title_height)

	available_size.y = available_size.y - title_height
end

function draw_grid(available_size)
	-- frames
	UiPush()
		UiAlign("left top")
		UiColor(0.7, 0.7, 0.7)

		-- top horizontal line
		UiPush()
			UiTranslate(0, 0)
			UiRect(available_size.x, 1)
		UiPop()

		-- middle horizontal line
		UiPush()
			UiTranslate(0, grid_header_height + 1)
			UiRect(available_size.x, 1)
		UiPop()

		-- bottom horizontal line
		UiPush()
			UiTranslate(0, available_size.y - 1)
			UiRect(available_size.x, 1)
		UiPop()

		-- left vertical line
		UiPush()
			UiTranslate(0, 0)
			UiRect(1, available_size.y)
		UiPop()

		-- middle vertical line
		UiPush()
			UiTranslate(last_max_key_width + 1, 0)
			UiRect(1, available_size.y)
		UiPop()

		-- right vertical line
		UiPush()
			UiTranslate(available_size.x - 1, 0)
			UiRect(1, available_size.y)
		UiPop()
	UiPop()

	-- header texts
	UiPush()
		UiAlign("center middle")
		UiFont("regular.ttf", grid_header_height - 2)
		UiColor(0.95, 0.95, 0.95)
		UiTextUniformHeight(true)

		UiPush()
			UiTranslate(1 + last_max_key_width / 2, 1 + grid_header_height / 2)
			UiText("Key")
		UiPop()

		UiPush()
			UiTranslate(1 + last_max_key_width + 1 + last_max_value_width / 2, 1 + grid_header_height / 2)
			UiText("Value")
		UiPop()
	UiPop()

	current_grid_visual_height = available_size.y - 1 - grid_header_height - 1 - 1

	UiPush()
		UiTranslate(1, 1 + grid_header_height + 1)

		UiWindow(available_size.x - 1 - 1, available_size.y - 1 - grid_header_height - 1 - 1, true, true)

		UiTranslate(0, -scroll_current_position)

		draw_node("options", "options", 0)
		draw_node("game", "game", 0)
		draw_node("savegame", "savegame", 0)
		draw_node("level", "level", 0)
	UiPop()
end

function draw_node(node_path, node_name, current_offset)
	current_drawn_row_count = current_drawn_row_count + 1

	local open = open_nodes[node_path]
	local children = ListKeys(node_path)

	local key_icon_image_size = 32
	local key_icon_visual_size = 12

	local key_left_padding = 2
	local key_middle_padding = 2
	local key_right_padding = 20

	local value_left_padding = 20
	local value_right_padding = 20

	local key_used_width = 0

	-- key
	UiPush()
		UiAlign("left top")

		-- button behavior
		if #children > 0 then
			UiPush()
				UiAlign("left top")
				if UiBlankButton(last_max_key_width, grid_row_height) and not InputReleased("return") then
					open_nodes[node_path] = not open
				end
			UiPop()
		end

		UiTranslate(current_offset + key_left_padding, 0)
		key_used_width = key_used_width + current_offset + key_left_padding

		-- icon
		if #children > 0 then
			UiPush()
				UiAlign("center middle")
				UiTranslate(key_icon_visual_size / 2, grid_row_height / 2)
				UiScale(key_icon_visual_size / key_icon_image_size)
				if open then
					UiRotate(-90)
				end
				UiImage("ui/arrow.png")
			UiPop()
		end

		UiTranslate(key_icon_visual_size + key_middle_padding, 0)
		key_used_width = key_used_width + key_icon_visual_size + key_middle_padding

		-- node name
		UiPush()
			UiAlign("left top")
			UiFont("regular.ttf", grid_row_height)
			UiColor(0.95, 0.95, 0.95)
			UiTextUniformHeight(true)

			local text_width, text_height, _, _ = UiText(node_name)
			key_used_width = key_used_width + text_width
		UiPop()

		key_used_width = key_used_width + key_right_padding
	UiPop()

	current_max_key_width = math.max(current_max_key_width, key_used_width)

	local value_used_width = 0

	-- value
	if #children == 0 then
		UiPush()
			UiTranslate(last_max_key_width + 1, 0)

			if currently_edited_node == node_path then
				if edit_value_text_box:has_focus() and not submit_pressed then
					UiPush()
						UiFont("regular.ttf", grid_row_height)
						edit_value_text_box:draw()
						value_used_width = value_used_width + edit_value_text_box:get_width()
					UiPop()
				else
					SetString(node_path, edit_value_text_box:get_text())
					edit_value_text_box = nil
					currently_edited_node = nil
					submit_pressed = false
				end
			end

			if currently_edited_node ~= node_path then
				-- button behavior
				UiPush()
					UiAlign("left top")
					if UiBlankButton(last_max_value_width, grid_row_height) and not InputReleased("return") then
						edit_value_text_box = UiTextBox:new(last_max_value_width)
						edit_value_text_box:set_text(GetString(node_path), true)
						edit_value_text_box:set_focus(true)
						currently_edited_node = node_path
					end
				UiPop()

				UiTranslate(value_left_padding, 0)

				UiPush()
					UiAlign("left top")
					UiFont("regular.ttf", grid_row_height)
					UiColor(0.9, 0.9, 0.5)
					UiTextUniformHeight(true)

					local text_width, text_height, _, _ = UiText(GetString(node_path))
					value_used_width = value_used_width + value_left_padding + text_width + value_right_padding
				UiPop()
			end
		UiPop()
	end

	current_max_value_width = math.max(current_max_value_width, value_used_width)

	UiTranslate(0, grid_row_height)

	-- children
	if open then
		for i = 1, #children do
			draw_node(node_path .. "." .. children[i], children[i], current_offset + children_offset)
		end
	end
end