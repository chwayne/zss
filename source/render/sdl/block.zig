// This file is a part of zss.
// Copyright (C) 2020-2021 Chadwain Holness
//
// This library is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this library.  If not, see <https://www.gnu.org/licenses/>.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const zss = @import("../../../zss.zig");
const BlockFormattingContext = zss.BlockFormattingContext;
const CSSUnit = zss.types.CSSUnit;
const Offset = zss.types.Offset;
const CSSRect = zss.types.CSSRect;
const Ratio = zss.types.Ratio;
const OffsetTree = zss.offset_tree.OffsetTree;
const OffsetInfo = zss.offset_tree.OffsetInfo;
const divCeil = zss.util.divCeil;
const sdl = zss.sdl;
usingnamespace zss.properties;

usingnamespace @import("SDL2");

// TODO delete this
fn TreeMap(comptime V: type) type {
    return @import("prefix-tree-map").PrefixTreeMapUnmanaged(zss.context.ContextSpecificBoxIdPart, V, zss.context.cmpPart);
}

const defaults = struct {
    const borders_node = TreeMap(Borders){};
    const border_colors_node = TreeMap(BorderColor){};
    const background_color_node = TreeMap(BackgroundColor){};
    const background_image_node = TreeMap(BackgroundImage){};
    const visual_effect_node = TreeMap(VisualEffect){};
};

const StackItem = struct {
    offset_tree: *const OffsetTree,
    offset: Offset,
    visible: bool,
    clip_rect: CSSRect,
    nodes: struct {
        tree: *const TreeMap(bool),
        borders: *const TreeMap(Borders),
        border_colors: *const TreeMap(BorderColor),
        background_color: *const TreeMap(BackgroundColor),
        background_image: *const TreeMap(BackgroundImage),
        visual_effect: *const TreeMap(VisualEffect),
    },
    indeces: struct {
        tree: usize = 0,
        borders: usize = 0,
        background_color: usize = 0,
        background_image: usize = 0,
        border_colors: usize = 0,
        visual_effect: usize = 0,
    } = .{},
};

/// Draws the background color, background image, and borders of the root
/// element box. This function should only be called with the block context
/// that contains the root element. This implements §Appendix E.2 Step 1.
///
/// TODO draw background images differently for the root element
pub const drawRootElementBlock = drawTopElementBlock;

/// Draws the background color, background image, and borders of a
/// block box. This implements §Appendix E.2 Step 2.
///
/// TODO support table boxes
pub fn drawTopElementBlock(
    context: *const BlockFormattingContext,
    offset_tree: *const OffsetTree,
    offset: Offset,
    clip_rect: CSSRect,
    renderer: *SDL_Renderer,
    pixel_format: *SDL_PixelFormat,
) void {
    const id = &[1]BlockFormattingContext.IdPart{context.tree.parts.items[0]};
    const visual_effect = context.visual_effect.get(id) orelse VisualEffect{};
    if (visual_effect.visibility == .Hidden) return;
    const borders = context.borders.get(id) orelse Borders{};
    const background_color = context.background_color.get(id) orelse BackgroundColor{};
    const background_image = context.background_image.get(id) orelse BackgroundImage{};
    const border_colors = context.border_colors.get(id) orelse BorderColor{};

    const boxes = zss.util.getThreeBoxes(offset, offset_tree.get(id).?, borders);
    drawBackgroundAndBorders(&boxes, borders, background_color, background_image, border_colors, clip_rect, renderer, pixel_format);
}

/// Draws the background color, background image, and borders of all of the
/// descendant boxes in a block context (i.e. excluding the top element).
/// This implements §Appendix E.2 Step 4.
///
/// TODO support table boxes
pub fn drawDescendantBlocks(
    context: *const BlockFormattingContext,
    allocator: *Allocator,
    offset_tree: *const OffsetTree,
    offset: Offset,
    initial_clip_rect: CSSRect,
    renderer: *SDL_Renderer,
    pixel_format: *SDL_PixelFormat,
) !void {
    if (context.tree.child(0) == null) return;

    var stack = try getInitialStack(context, allocator, offset_tree, offset, initial_clip_rect);
    defer stack.deinit();
    assert(SDL_RenderSetClipRect(renderer, &sdl.cssRectToSdlRect(stack.items[0].clip_rect)) == 0);

    stackLoop: while (stack.items.len > 0) {
        const stack_item = &stack.items[stack.items.len - 1];
        const nodes = &stack_item.nodes;
        const indeces = &stack_item.indeces;

        while (indeces.tree < nodes.tree.numChildren()) {
            defer indeces.tree += 1;
            const offsets = stack_item.offset_tree.value(indeces.tree);
            const part = nodes.tree.part(indeces.tree);

            const borders: struct { data: Borders, child: *const TreeMap(Borders) } =
                if (indeces.borders < nodes.borders.numChildren() and nodes.borders.parts.items[indeces.borders] == part)
            blk: {
                const data = nodes.borders.value(indeces.borders);
                const child = nodes.borders.child(indeces.borders);
                indeces.borders += 1;
                break :blk .{ .data = data, .child = child orelse &defaults.borders_node };
            } else .{ .data = Borders{}, .child = &defaults.borders_node };
            const border_colors: struct { data: BorderColor, child: *const TreeMap(BorderColor) } =
                if (indeces.border_colors < nodes.border_colors.numChildren() and nodes.border_colors.parts.items[indeces.border_colors] == part)
            blk: {
                const data = nodes.border_colors.value(indeces.border_colors);
                const child = nodes.border_colors.child(indeces.border_colors);
                indeces.border_colors += 1;
                break :blk .{ .data = data, .child = child orelse &defaults.border_colors_node };
            } else .{ .data = BorderColor{}, .child = &defaults.border_colors_node };
            const background_color: struct { data: BackgroundColor, child: *const TreeMap(BackgroundColor) } =
                if (indeces.background_color < nodes.background_color.numChildren() and nodes.background_color.parts.items[indeces.background_color] == part)
            blk: {
                const data = nodes.background_color.value(indeces.background_color);
                const child = nodes.background_color.child(indeces.background_color);
                indeces.background_color += 1;
                break :blk .{ .data = data, .child = child orelse &defaults.background_color_node };
            } else .{ .data = BackgroundColor{}, .child = &defaults.background_color_node };
            const background_image: struct { data: BackgroundImage, child: *const TreeMap(BackgroundImage) } =
                if (indeces.background_image < nodes.background_image.numChildren() and nodes.background_image.parts.items[indeces.background_image] == part)
            blk: {
                const data = nodes.background_image.value(indeces.background_image);
                const child = nodes.background_image.child(indeces.background_image);
                indeces.background_image += 1;
                break :blk .{ .data = data, .child = child orelse &defaults.background_image_node };
            } else .{ .data = BackgroundImage{}, .child = &defaults.background_image_node };
            const visual_effect: struct { data: VisualEffect, child: *const TreeMap(VisualEffect) } =
                if (indeces.visual_effect < nodes.visual_effect.numChildren() and nodes.visual_effect.parts.items[indeces.visual_effect] == part)
            blk: {
                const data = nodes.visual_effect.value(indeces.visual_effect);
                const child = nodes.visual_effect.child(indeces.visual_effect);
                indeces.visual_effect += 1;
                break :blk .{ .data = data, .child = child orelse &defaults.visual_effect_node };
            } else .{ .data = VisualEffect{ .visibility = if (stack_item.visible) .Visible else .Hidden }, .child = &defaults.visual_effect_node };

            const boxes = zss.util.getThreeBoxes(stack_item.offset, offsets, borders.data);

            if (visual_effect.data.visibility == .Visible) {
                drawBackgroundAndBorders(&boxes, borders.data, background_color.data, background_image.data, border_colors.data, stack_item.clip_rect, renderer, pixel_format);
            }

            if (nodes.tree.child(indeces.tree)) |child_tree| {
                const new_clip_rect = switch (visual_effect.data.overflow) {
                    .Visible => stack_item.clip_rect,
                    .Hidden =>
                    // NOTE if there is no intersection here, then
                    // child elements don't need to be rendered
                    stack_item.clip_rect.intersect(boxes.padding),
                };
                assert(SDL_RenderSetClipRect(renderer, &sdl.cssRectToSdlRect(new_clip_rect)) == 0);

                try stack.append(StackItem{
                    .offset_tree = stack_item.offset_tree.child(indeces.tree).?,
                    .offset = stack_item.offset.add(offsets.content_top_left),
                    .visible = visual_effect.data.visibility == .Visible,
                    .clip_rect = new_clip_rect,
                    .nodes = .{
                        .tree = child_tree,
                        .borders = borders.child,
                        .border_colors = border_colors.child,
                        .background_color = background_color.child,
                        .background_image = background_image.child,
                        .visual_effect = visual_effect.child,
                    },
                });
                continue :stackLoop;
            }
        }

        _ = stack.pop();
    }
}

fn getInitialStack(
    context: *const BlockFormattingContext,
    allocator: *Allocator,
    offset_tree: *const OffsetTree,
    offset: Offset,
    initial_clip_rect: CSSRect,
) !ArrayList(StackItem) {
    const id = &[1]BlockFormattingContext.IdPart{context.tree.parts.items[0]};
    const tree = context.tree.child(0).?;
    const offset_tree_child = offset_tree.child(0).?;
    const borders: struct { data: Borders, child: *const TreeMap(Borders) } = blk: {
        const find = context.borders.find(id);
        if (find.wasFound()) {
            break :blk .{ .data = find.parent.?.value(find.index), .child = find.parent.?.child(find.index) orelse &defaults.borders_node };
        } else {
            break :blk .{ .data = Borders{}, .child = &defaults.borders_node };
        }
    };
    const border_colors = blk: {
        const find = context.border_colors.find(id);
        if (find.wasFound()) {
            break :blk find.parent.?.child(find.index) orelse &defaults.border_colors_node;
        } else {
            break :blk &defaults.border_colors_node;
        }
    };
    const background_color = blk: {
        const find = context.background_color.find(id);
        if (find.wasFound()) {
            break :blk find.parent.?.child(find.index) orelse &defaults.background_color_node;
        } else {
            break :blk &defaults.background_color_node;
        }
    };
    const background_image = blk: {
        const find = context.background_image.find(id);
        if (find.wasFound()) {
            break :blk find.parent.?.child(find.index) orelse &defaults.background_image_node;
        } else {
            break :blk &defaults.background_image_node;
        }
    };
    const visual_effect: struct { data: VisualEffect, child: *const TreeMap(VisualEffect) } = blk: {
        const find = context.visual_effect.find(id);
        if (find.wasFound()) {
            break :blk .{ .data = find.parent.?.value(find.index), .child = find.parent.?.child(find.index) orelse &defaults.visual_effect_node };
        } else {
            break :blk .{ .data = VisualEffect{}, .child = &defaults.visual_effect_node };
        }
    };

    const offset_info = offset_tree.get(id).?;
    const clip_rect = switch (visual_effect.data.overflow) {
        .Visible => initial_clip_rect,
        .Hidden => blk: {
            const padding_rect = CSSRect{
                .x = offset.x + offset_info.border_top_left.x + borders.data.left,
                .y = offset.y + offset_info.border_top_left.y + borders.data.top,
                .w = (offset_info.border_bottom_right.x - borders.data.right) - (offset_info.border_top_left.x + borders.data.left),
                .h = (offset_info.border_bottom_right.y - borders.data.bottom) - (offset_info.border_top_left.y + borders.data.top),
            };

            // NOTE if there is no intersection here, then
            // child elements don't need to be rendered
            break :blk initial_clip_rect.intersect(padding_rect);
        },
    };

    var result = ArrayList(StackItem).init(allocator);
    try result.append(StackItem{
        .offset_tree = offset_tree_child,
        .offset = offset.add(offset_info.content_top_left),
        .visible = visual_effect.data.visibility == .Visible,
        .clip_rect = clip_rect,
        .nodes = .{
            .tree = tree,
            .borders = borders.child,
            .border_colors = border_colors,
            .background_color = background_color,
            .background_image = background_image,
            .visual_effect = visual_effect.child,
        },
    });
    return result;
}

fn drawBackgroundAndBorders(
    boxes: *const zss.types.ThreeBoxes,
    borders: Borders,
    background_color: BackgroundColor,
    background_image: BackgroundImage,
    border_colors: BorderColor,
    clip_rect: CSSRect,
    renderer: *SDL_Renderer,
    pixel_format: *SDL_PixelFormat,
) void {
    const bg_clip_rect = sdl.cssRectToSdlRect(switch (background_image.clip) {
        .Border => boxes.border,
        .Padding => boxes.padding,
        .Content => boxes.content,
    });

    // draw background color
    drawBackgroundColor(renderer, pixel_format, bg_clip_rect, background_color.rgba);

    // draw background image
    if (background_image.image) |texture_ptr| {
        const texture = @ptrCast(*SDL_Texture, texture_ptr);
        var tw: c_int = undefined;
        var th: c_int = undefined;
        assert(SDL_QueryTexture(texture, null, null, &tw, &th) == 0);
        const origin_rect = sdl.cssRectToSdlRect(switch (background_image.origin) {
            .Border => boxes.border,
            .Padding => boxes.padding,
            .Content => boxes.content,
        });
        const size = SDL_Point{
            .x = @floatToInt(c_int, background_image.size.width * @intToFloat(f32, tw)),
            .y = @floatToInt(c_int, background_image.size.height * @intToFloat(f32, th)),
        };
        drawBackgroundImage(
            renderer,
            texture,
            origin_rect,
            bg_clip_rect,
            SDL_Point{
                .x = origin_rect.x + @floatToInt(c_int, @intToFloat(f32, origin_rect.w - size.x) * background_image.position.horizontal),
                .y = origin_rect.y + @floatToInt(c_int, @intToFloat(f32, origin_rect.h - size.y) * background_image.position.vertical),
            },
            size,
            .{
                .x = switch (background_image.repeat.x) {
                    .None => .NoRepeat,
                    .Repeat => .Repeat,
                    .Space => .Space,
                },
                .y = switch (background_image.repeat.y) {
                    .None => .NoRepeat,
                    .Repeat => .Repeat,
                    .Space => .Space,
                },
            },
        );
    }

    // draw borders
    drawBordersSolid(renderer, pixel_format, boxes, &borders, &border_colors);
}

fn drawBordersSolid(renderer: *SDL_Renderer, pixel_format: *SDL_PixelFormat, boxes: *const zss.types.ThreeBoxes, borders: *const Borders, colors: *const BorderColor) void {
    const outer_left = sdl.cssUnitToSdlPixel(boxes.border.x);
    const inner_left = sdl.cssUnitToSdlPixel(boxes.border.x + borders.left);
    const inner_right = sdl.cssUnitToSdlPixel(boxes.border.x + boxes.border.w - borders.right);
    const outer_right = sdl.cssUnitToSdlPixel(boxes.border.x + boxes.border.w);

    const outer_top = sdl.cssUnitToSdlPixel(boxes.border.y);
    const inner_top = sdl.cssUnitToSdlPixel(boxes.border.y + borders.top);
    const inner_bottom = sdl.cssUnitToSdlPixel(boxes.border.y + boxes.border.h - borders.bottom);
    const outer_bottom = sdl.cssUnitToSdlPixel(boxes.border.y + boxes.border.h);

    const color_mapped = [_][4]u8{
        sdl.rgbaMap(pixel_format, colors.top_rgba),
        sdl.rgbaMap(pixel_format, colors.right_rgba),
        sdl.rgbaMap(pixel_format, colors.bottom_rgba),
        sdl.rgbaMap(pixel_format, colors.left_rgba),
    };

    const rects = [_]SDL_Rect{
        // top border
        SDL_Rect{
            .x = inner_left,
            .y = outer_top,
            .w = inner_right - inner_left,
            .h = inner_top - outer_top,
        },
        // right border
        SDL_Rect{
            .x = inner_right,
            .y = inner_top,
            .w = outer_right - inner_right,
            .h = inner_bottom - inner_top,
        },
        // bottom border
        SDL_Rect{
            .x = inner_left,
            .y = inner_bottom,
            .w = inner_right - inner_left,
            .h = outer_bottom - inner_bottom,
        },
        //left border
        SDL_Rect{
            .x = outer_left,
            .y = inner_top,
            .w = inner_left - outer_left,
            .h = inner_bottom - inner_top,
        },
    };

    comptime var i = 0;
    inline while (i < 4) : (i += 1) {
        const c = color_mapped[i];
        assert(SDL_SetRenderDrawColor(renderer, c[0], c[1], c[2], c[3]) == 0);
        assert(SDL_RenderFillRect(renderer, &rects[i]) == 0);
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
    renderer: *SDL_Renderer,
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

fn drawVerticalLine(renderer: *SDL_Renderer, x: c_int, y: c_int, y_low: c_int, y_high: c_int, first_color: [4]u8, second_color: [4]u8) void {
    assert(SDL_SetRenderDrawColor(renderer, first_color[0], first_color[1], first_color[2], first_color[3]) == 0);
    var i = y;
    while (i < y_high) : (i += 1) {
        assert(SDL_RenderDrawPoint(renderer, x, i) == 0);
    }

    assert(SDL_SetRenderDrawColor(renderer, second_color[0], second_color[1], second_color[2], second_color[3]) == 0);
    i = y_low;
    while (i < y) : (i += 1) {
        assert(SDL_RenderDrawPoint(renderer, x, i) == 0);
    }
}

fn drawBackgroundColor(
    renderer: *SDL_Renderer,
    pixel_format: *SDL_PixelFormat,
    painting_area: SDL_Rect,
    color_rgba: u32,
) void {
    const color_mapped = sdl.rgbaMap(pixel_format, color_rgba);
    assert(SDL_SetRenderDrawColor(renderer, color_mapped[0], color_mapped[1], color_mapped[2], color_mapped[3]) == 0);
    assert(SDL_RenderFillRect(renderer, &painting_area) == 0);
}

/// Represents one of the ways in which background images can be repeated.
/// Note that "background-repeat: round" is not explicitly supported, but can
/// be achieved by first resizing the image and using '.Repeat'.
pub const Repeat = enum { NoRepeat, Repeat, Space };

fn drawBackgroundImage(
    renderer: *SDL_Renderer,
    texture: *SDL_Texture,
    positioning_area: SDL_Rect,
    painting_area: SDL_Rect,
    position: SDL_Point,
    size: SDL_Point,
    repeat: struct { x: Repeat, y: Repeat },
) void {
    if (size.x == 0 or size.y == 0) return;
    const dimensions = blk: {
        var w: c_int = undefined;
        var h: c_int = undefined;
        assert(SDL_QueryTexture(texture, null, null, &w, &h) == 0);
        break :blk .{ .w = w, .h = h };
    };
    if (dimensions.w == 0 or dimensions.h == 0) return;

    const info_x = getBackgroundImageRepeatInfo(
        repeat.x,
        @intCast(c_uint, painting_area.w),
        positioning_area.x - painting_area.x,
        @intCast(c_uint, positioning_area.w),
        position.x - positioning_area.x,
        @intCast(c_uint, size.x),
    );
    const info_y = getBackgroundImageRepeatInfo(
        repeat.y,
        @intCast(c_uint, painting_area.h),
        positioning_area.y - painting_area.y,
        @intCast(c_uint, positioning_area.h),
        position.y - positioning_area.y,
        @intCast(c_uint, size.y),
    );

    var i: c_int = info_x.start_index;
    while (i < info_x.start_index + @intCast(c_int, info_x.count)) : (i += 1) {
        var j: c_int = info_y.start_index;
        while (j < info_y.start_index + @intCast(c_int, info_y.count)) : (j += 1) {
            const image_rect = SDL_Rect{
                .x = positioning_area.x + info_x.offset + @divFloor(i * (size.x * @intCast(c_int, info_x.space.den) + @intCast(c_int, info_x.space.num)), @intCast(c_int, info_x.space.den)),
                .y = positioning_area.y + info_y.offset + @divFloor(j * (size.y * @intCast(c_int, info_y.space.den) + @intCast(c_int, info_y.space.num)), @intCast(c_int, info_y.space.den)),
                .w = size.x,
                .h = size.y,
            };
            var intersection = @as(SDL_Rect, undefined);
            assert(SDL_IntersectRect(&painting_area, &image_rect, &intersection) == .SDL_TRUE);
            assert(SDL_RenderCopy(
                renderer,
                texture,
                &SDL_Rect{
                    .x = @divTrunc((intersection.x - image_rect.x) * dimensions.w, size.x),
                    .y = @divTrunc((intersection.y - image_rect.y) * dimensions.h, size.y),
                    .w = @divTrunc(intersection.w * dimensions.w, size.x),
                    .h = @divTrunc(intersection.h * dimensions.h, size.y),
                },
                &intersection,
            ) == 0);
        }
    }
}

fn getBackgroundImageRepeatInfo(
    repeat: Repeat,
    painting_area_size: c_uint,
    positioning_area_offset: c_int,
    positioning_area_size: c_uint,
    image_offset: c_int,
    image_size: c_uint,
) struct {
    count: c_uint,
    space: Ratio(c_uint),
    offset: c_int,
    start_index: c_int,
} {
    return switch (repeat) {
        .NoRepeat => .{
            .count = 1,
            .space = Ratio(c_uint){ .num = 0, .den = 1 },
            .offset = image_offset,
            .start_index = 0,
        },
        .Repeat => blk: {
            const before = divCeil(c_int, image_offset + positioning_area_offset, @intCast(c_int, image_size));
            const after = divCeil(c_int, @intCast(c_int, painting_area_size) - positioning_area_offset - image_offset - @intCast(c_int, image_size), @intCast(c_int, image_size));
            break :blk .{
                .count = @intCast(c_uint, before + after + 1),
                .space = Ratio(c_uint){ .num = 0, .den = 1 },
                .offset = image_offset,
                .start_index = -before,
            };
        },
        .Space => blk: {
            const positioning_area_count = positioning_area_size / image_size;
            const space = positioning_area_size % image_size;
            const before = divCeil(c_int, @intCast(c_int, positioning_area_count) * positioning_area_offset, @intCast(c_int, positioning_area_size));
            const after = divCeil(c_int, @intCast(c_int, positioning_area_size) * (@intCast(c_int, painting_area_size) - @intCast(c_int, positioning_area_size) - positioning_area_offset), @intCast(c_int, positioning_area_size));
            const count = @intCast(c_uint, before + after + @intCast(c_int, std.math.max(1, positioning_area_count)));
            break :blk .{
                .count = count,
                .space = Ratio(c_uint){ .num = space, .den = std.math.max(2, positioning_area_count) - 1 },
                .offset = image_offset * @boolToInt(count == 1),
                .start_index = -before,
            };
        },
    };
}
