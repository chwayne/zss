const std = @import("std");
const assert = std.debug.assert;
const sdl = @import("SDL2");
const util = @import("../../util.zig");

pub fn rgbaMap(pixel_format: *sdl.SDL_PixelFormat, color: u32) [4]u8 {
    const color_le = std.mem.nativeToLittle(u32, color);
    const mapped = sdl.SDL_MapRGBA(
        pixel_format,
        @truncate(u8, color_le >> 24),
        @truncate(u8, color_le >> 16),
        @truncate(u8, color_le >> 8),
        @truncate(u8, color_le),
    );
    var rgba = @as([4]u8, undefined);
    sdl.SDL_GetRGBA(mapped, pixel_format, &rgba[0], &rgba[1], &rgba[2], &rgba[3]);
    return rgba;
}

pub const Widths = struct {
    top: c_int,
    right: c_int,
    bottom: c_int,
    left: c_int,
};

pub const Colors = struct {
    top_rgba: u32,
    right_rgba: u32,
    bottom_rgba: u32,
    left_rgba: u32,
};

pub const BackgroundClip = enum {
    Border,
    Padding,
    Content,
};

pub const BackgroundRepeatStyle = enum {
    None,
    Repeat,
    Space,
    Round,
};

pub const BackgroundRepeat = struct {
    x: BackgroundRepeatStyle,
    y: BackgroundRepeatStyle,
};

pub const ImageSize = struct {
    w: c_int,
    h: c_int,
};

pub fn drawBordersSolid(renderer: *sdl.SDL_Renderer, pixel_format: *sdl.SDL_PixelFormat, border_rect: sdl.SDL_Rect, widths: Widths, colors: Colors) void {
    const outer_left = border_rect.x;
    const inner_left = border_rect.x + widths.left;
    const inner_right = border_rect.x + border_rect.w - widths.right;
    const outer_right = border_rect.x + border_rect.w;

    const outer_top = border_rect.y;
    const inner_top = border_rect.y + widths.top;
    const inner_bottom = border_rect.y + border_rect.h - widths.bottom;
    const outer_bottom = border_rect.y + border_rect.h;

    const color_mapped = [_][4]u8{
        rgbaMap(pixel_format, colors.top_rgba),
        rgbaMap(pixel_format, colors.right_rgba),
        rgbaMap(pixel_format, colors.bottom_rgba),
        rgbaMap(pixel_format, colors.left_rgba),
    };

    const rects = [_]sdl.SDL_Rect{
        // top border
        sdl.SDL_Rect{
            .x = inner_left,
            .y = outer_top,
            .w = inner_right - inner_left,
            .h = inner_top - outer_top,
        },
        // right border
        sdl.SDL_Rect{
            .x = inner_right,
            .y = inner_top,
            .w = outer_right - inner_right,
            .h = inner_bottom - inner_top,
        },
        // bottom border
        sdl.SDL_Rect{
            .x = inner_left,
            .y = inner_bottom,
            .w = inner_right - inner_left,
            .h = outer_bottom - inner_bottom,
        },
        //left border
        sdl.SDL_Rect{
            .x = outer_left,
            .y = inner_top,
            .w = inner_left - outer_left,
            .h = inner_bottom - inner_top,
        },
    };

    comptime var i = 0;
    inline while (i < 4) : (i += 1) {
        const c = color_mapped[i];
        assert(sdl.SDL_SetRenderDrawColor(renderer, c[0], c[1], c[2], c[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &rects[i]) == 0);
    }

    drawBordersSolidCorners(renderer, outer_left, inner_left, outer_top, inner_top, color_mapped[3], color_mapped[0], true);
    drawBordersSolidCorners(renderer, inner_right, outer_right, inner_bottom, outer_bottom, color_mapped[2], color_mapped[1], true);
    drawBordersSolidCorners(renderer, outer_right, inner_right, outer_top, inner_top, color_mapped[1], color_mapped[0], false);
    drawBordersSolidCorners(renderer, inner_left, outer_left, inner_bottom, outer_bottom, color_mapped[2], color_mapped[3], false);
}

// TODO This function doesn't draw in a very satisfactory way.
// It ends up making borders look asymmetrical by 1 pixel.
// It's also probably slow because it draws every point 1-by-1
// instead of drawing lines. In the future I hope to get rid of
// this function entirely, replacing it with a function that masks
// out the portion of a border image that shouldn't be drawn. This
// would allow me to draw all kinds of border styles without
// needing specific code for each one.
fn drawBordersSolidCorners(
    renderer: *sdl.SDL_Renderer,
    x1: c_int,
    x2: c_int,
    y_low: c_int,
    y_high: c_int,
    first_color: [4]u8,
    second_color: [4]u8,
    comptime isTopLeftOrBottomRight: bool,
) void {
    const dx = if (isTopLeftOrBottomRight) x2 - x1 else x1 - x2;
    const dy = y_high - y_low;

    if (isTopLeftOrBottomRight) {
        var x = x1;
        while (x < x2) : (x += 1) {
            const num = (x - x1) * dy;
            const mod = @mod(num, dx);
            const y = y_low + @divFloor(num, dx) + @boolToInt(2 * mod >= dx);
            drawVerticalLine(renderer, x, y, y_low, y_high, first_color, second_color);
        }
    } else {
        var x = x2;
        while (x < x1) : (x += 1) {
            const num = (x1 - 1 - x) * dy;
            const mod = @mod(num, dx);
            const y = y_low + @divFloor(num, dx) + @boolToInt(2 * mod >= dx);
            drawVerticalLine(renderer, x, y, y_low, y_high, first_color, second_color);
        }
    }
}

fn drawVerticalLine(renderer: *sdl.SDL_Renderer, x: c_int, y: c_int, y_low: c_int, y_high: c_int, first_color: [4]u8, second_color: [4]u8) void {
    assert(sdl.SDL_SetRenderDrawColor(renderer, first_color[0], first_color[1], first_color[2], first_color[3]) == 0);
    var i = y;
    while (i < y_high) : (i += 1) {
        assert(sdl.SDL_RenderDrawPoint(renderer, x, i) == 0);
    }

    assert(sdl.SDL_SetRenderDrawColor(renderer, second_color[0], second_color[1], second_color[2], second_color[3]) == 0);
    i = y_low;
    while (i < y) : (i += 1) {
        assert(sdl.SDL_RenderDrawPoint(renderer, x, i) == 0);
    }
}

pub fn drawBackgroundColor(
    renderer: *sdl.SDL_Renderer,
    pixel_format: *sdl.SDL_PixelFormat,
    painting_area: sdl.SDL_Rect,
    color_rgba: u32,
) void {
    const color_mapped = rgbaMap(pixel_format, color_rgba);
    assert(sdl.SDL_SetRenderDrawColor(renderer, color_mapped[0], color_mapped[1], color_mapped[2], color_mapped[3]) == 0);
    assert(sdl.SDL_RenderFillRect(renderer, &painting_area) == 0);
}

pub fn drawBackgroundImage(
    renderer: *sdl.SDL_Renderer,
    texture: *sdl.SDL_Texture,
    positioning_area: sdl.SDL_Rect,
    painting_area: sdl.SDL_Rect,
    position: sdl.SDL_Point,
    size: ImageSize,
    repeat: BackgroundRepeat,
) void {
    if (size.w == 0 or size.h == 0) return;
    const unscaled_size = blk: {
        var w: c_int = undefined;
        var h: c_int = undefined;
        assert(sdl.SDL_QueryTexture(texture, null, null, &w, &h) == 0);
        break :blk .{ .w = w, .h = h };
    };
    if (unscaled_size.w == 0 or unscaled_size.h == 0) return;

    const info_x = getBackgroundImageRepeatInfo(
        repeat.x,
        painting_area.w,
        positioning_area.x - painting_area.x,
        positioning_area.w,
        position.x - positioning_area.x,
        size.w,
    );
    const info_y = getBackgroundImageRepeatInfo(
        repeat.y,
        painting_area.h,
        positioning_area.y - painting_area.y,
        positioning_area.h,
        position.y - positioning_area.y,
        size.h,
    );

    var i = info_x.start_index;
    while (i < info_x.start_index + info_x.count) : (i += 1) {
        var j = info_y.start_index;
        while (j < info_y.start_index + info_y.count) : (j += 1) {
            const image_rect = sdl.SDL_Rect{
                .x = positioning_area.x + info_x.offset + @divFloor(i * (size.w * info_x.space.den + info_x.space.num), info_x.space.den),
                .y = positioning_area.y + info_y.offset + @divFloor(j * (size.h * info_y.space.den + info_y.space.num), info_y.space.den),
                .w = size.w,
                .h = size.h,
            };
            var intersection = @as(sdl.SDL_Rect, undefined);
            // getBackgroundImageRepeatInfo should never return info that would make us draw
            // an image that is completely outside of the background painting area.
            assert(sdl.SDL_IntersectRect(&painting_area, &image_rect, &intersection) == .SDL_TRUE);
            assert(sdl.SDL_RenderCopy(
                renderer,
                texture,
                &sdl.SDL_Rect{
                    .x = @divFloor((intersection.x - image_rect.x) * unscaled_size.w, size.w),
                    .y = @divFloor((intersection.y - image_rect.y) * unscaled_size.h, size.h),
                    .w = @divFloor(intersection.w * unscaled_size.w, size.w),
                    .h = @divFloor(intersection.h * unscaled_size.h, size.h),
                },
                &intersection,
            ) == 0);
        }
    }
}

const GetBackgroundImageRepeatInfoReturnType = struct {
    /// The index of the left-most/top-most image to be drawn.
    start_index: c_int,
    /// The number of images to draw. Always positive.
    count: c_int,
    /// The amount of space to leave between each image. Always positive.
    space: util.Ratio(c_int),
    /// The offset of the top/left of the image with index 0 from the top/left of the positioning area.
    offset: c_int,
};

fn getBackgroundImageRepeatInfo(
    repeat: BackgroundRepeatStyle,
    /// Must be greater than or equal to 0.
    painting_area_size: c_int,
    /// The offset of the top/left of the positioning area from the top/left of the painting area.
    positioning_area_offset: c_int,
    /// Must be greater than or equal to 0.
    positioning_area_size: c_int,
    /// The offset of the top/left of the image with index 0 from the top/left of the positioning area.
    image_offset: c_int,
    /// Must be strictly greater than 0.
    image_size: c_int,
) GetBackgroundImageRepeatInfoReturnType {
    return switch (repeat) {
        .None => .{
            .start_index = 0,
            .count = 1,
            .space = util.Ratio(c_int){ .num = 0, .den = 1 },
            .offset = image_offset,
        },
        .Repeat => blk: {
            const before = util.divCeil(image_offset + positioning_area_offset, image_size);
            const after = util.divCeil(painting_area_size - positioning_area_offset - image_offset - image_size, image_size);
            break :blk .{
                .start_index = -before,
                .count = before + after + 1,
                .space = util.Ratio(c_int){ .num = 0, .den = 1 },
                .offset = image_offset,
            };
        },
        .Space => blk: {
            const positioning_area_count = @divFloor(positioning_area_size, image_size);
            if (positioning_area_count <= 1) {
                break :blk GetBackgroundImageRepeatInfoReturnType{
                    .start_index = 0,
                    .count = 1,
                    .space = util.Ratio(c_int){ .num = 0, .den = 1 },
                    .offset = image_offset,
                };
            } else {
                const space = @mod(positioning_area_size, image_size);
                const before = util.divCeil(
                    (positioning_area_count - 1) * positioning_area_offset - space,
                    positioning_area_size - image_size,
                );
                const after = util.divCeil(
                    (positioning_area_count - 1) * (painting_area_size - positioning_area_size - positioning_area_offset) - space,
                    positioning_area_size - image_size,
                );
                break :blk GetBackgroundImageRepeatInfoReturnType{
                    .start_index = -before,
                    .count = before + after + positioning_area_count,
                    .space = util.Ratio(c_int){ .num = space, .den = positioning_area_count - 1 },
                    .offset = 0,
                };
            }
        },
        .Round => @panic("TODO SDL: Background image round repeat style"),
    };
}

pub fn drawInlineBox(
    renderer: *sdl.SDL_Renderer,
    pixel_format: *sdl.SDL_PixelFormat,
    baseline_position: sdl.SDL_Point,
    ascender: c_int,
    descender: c_int,
    border: Widths,
    padding: Widths,
    border_colors: Colors,
    background_color_rgba: u32,
    background_clip: BackgroundClip,
    middle_length: c_int,
    draw_start: bool,
    draw_end: bool,
) void {
    // NOTE The height of the content box is based on the ascender and descender.
    const content_top_y = baseline_position.y - ascender;
    const padding_top_y = content_top_y - padding.top;
    const border_top_y = padding_top_y - border.top;
    const content_bottom_y = baseline_position.y - descender;
    const padding_bottom_y = content_bottom_y + padding.bottom;
    const border_bottom_y = padding_bottom_y + border.bottom;

    { // background color
        var background_clip_rect = sdl.SDL_Rect{
            .x = baseline_position.x,
            .y = undefined,
            .w = middle_length,
            .h = undefined,
        };
        switch (background_clip) {
            .Border => {
                background_clip_rect.y = border_top_y;
                background_clip_rect.h = border_bottom_y - border_top_y;
                if (draw_start) background_clip_rect.w += padding.left + border.left;
                if (draw_end) background_clip_rect.w += padding.right + border.right;
            },
            .Padding => {
                background_clip_rect.y = padding_top_y;
                background_clip_rect.h = padding_bottom_y - padding_top_y;
                if (draw_start) {
                    background_clip_rect.x += border.left;
                    background_clip_rect.w += padding.left;
                }
                if (draw_end) background_clip_rect.w += padding.right;
            },
            .Content => {
                background_clip_rect.y = content_top_y;
                background_clip_rect.h = content_bottom_y - content_top_y;
                if (draw_start) background_clip_rect.x += padding.left + border.left;
            },
        }

        const color = rgbaMap(pixel_format, background_color_rgba);
        assert(sdl.SDL_SetRenderDrawColor(renderer, color[0], color[1], color[2], color[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &background_clip_rect) == 0);
    }

    const top_color = rgbaMap(pixel_format, border_colors.top_rgba);
    const bottom_color = rgbaMap(pixel_format, border_colors.bottom_rgba);
    var top_bottom_border_x = baseline_position.x;
    var top_bottom_border_w = middle_length;
    var section_start_x = baseline_position.x;

    if (draw_start) {
        const rect = sdl.SDL_Rect{
            .x = section_start_x,
            .y = padding_top_y,
            .w = border.left,
            .h = ascender + descender + padding.top + padding.bottom,
        };
        const left_color = rgbaMap(pixel_format, border_colors.left_rgba);

        // left edge
        assert(sdl.SDL_SetRenderDrawColor(renderer, left_color[0], left_color[1], left_color[2], left_color[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &rect) == 0);

        // top left corner
        drawBordersSolidCorners(
            renderer,
            section_start_x,
            section_start_x + border.left,
            border_top_y,
            padding_top_y,
            left_color,
            top_color,
            true,
        );
        // bottom left corner
        drawBordersSolidCorners(
            renderer,
            section_start_x + border.left,
            section_start_x,
            padding_bottom_y,
            border_bottom_y,
            bottom_color,
            left_color,
            false,
        );

        top_bottom_border_x += border.left;
        top_bottom_border_w += padding.left;
        section_start_x += border.left + padding.left;
    }

    section_start_x += middle_length;

    if (draw_end) {
        const rect = sdl.SDL_Rect{
            .x = section_start_x + padding.right,
            .y = padding_top_y,
            .w = border.right,
            .h = ascender + descender + padding.top + padding.bottom,
        };
        const right_color = rgbaMap(pixel_format, border_colors.right_rgba);

        // right edge
        assert(sdl.SDL_SetRenderDrawColor(renderer, right_color[0], right_color[1], right_color[2], right_color[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &rect) == 0);

        // top right corner
        drawBordersSolidCorners(
            renderer,
            section_start_x + border.right + padding.right,
            section_start_x + padding.right,
            border_top_y,
            padding_top_y,
            right_color,
            top_color,
            false,
        );
        // bottom right corner
        drawBordersSolidCorners(
            renderer,
            section_start_x + padding.right,
            section_start_x + border.right + padding.right,
            padding_bottom_y,
            border_bottom_y,
            bottom_color,
            right_color,
            true,
        );

        top_bottom_border_w += padding.right;
    }

    section_start_x -= middle_length;

    {
        const rects = [2]sdl.SDL_Rect{
            // top edge
            sdl.SDL_Rect{
                .x = top_bottom_border_x,
                .y = border_top_y,
                .w = top_bottom_border_w,
                .h = border.top,
            },
            // bottom edge
            sdl.SDL_Rect{
                .x = top_bottom_border_x,
                .y = padding_bottom_y,
                .w = top_bottom_border_w,
                .h = border.bottom,
            },
        };

        assert(sdl.SDL_SetRenderDrawColor(renderer, top_color[0], top_color[1], top_color[2], top_color[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &rects[0]) == 0);
        assert(sdl.SDL_SetRenderDrawColor(renderer, bottom_color[0], bottom_color[1], bottom_color[2], bottom_color[3]) == 0);
        assert(sdl.SDL_RenderFillRect(renderer, &rects[1]) == 0);
    }
}
