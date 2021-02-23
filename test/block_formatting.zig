const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const zss = @import("zss");

const sdl = @import("SDL2");
usingnamespace @import("sdl/render_sdl.zig");

pub fn main() !void {
    assert(sdl.SDL_Init(sdl.SDL_INIT_VIDEO) == 0);
    defer sdl.SDL_Quit();

    const width = 800;
    const height = 600;
    const window = sdl.SDL_CreateWindow(
        "An sdl.SDL Window.",
        sdl.SDL_WINDOWPOS_CENTERED_MASK,
        sdl.SDL_WINDOWPOS_CENTERED_MASK,
        width,
        height,
        sdl.SDL_WINDOW_SHOWN | sdl.SDL_WINDOW_RESIZABLE,
    ) orelse unreachable;
    defer sdl.SDL_DestroyWindow(window);

    const renderer = sdl.SDL_CreateRenderer(
        window,
        -1,
        sdl.SDL_RENDERER_ACCELERATED | sdl.SDL_RENDERER_PRESENTVSYNC,
    ) orelse unreachable;
    defer sdl.SDL_DestroyRenderer(renderer);

    const window_texture = sdl.SDL_GetRenderTarget(renderer);

    const texture_pixel_format = sdl.SDL_AllocFormat(sdl.SDL_PIXELFORMAT_RGBA32) orelse unreachable;
    defer sdl.SDL_FreeFormat(texture_pixel_format);
    const texture = sdl.SDL_CreateTexture(
        renderer,
        texture_pixel_format.*.format,
        sdl.SDL_TEXTUREACCESS_TARGET,
        width,
        height,
    ) orelse unreachable;
    defer sdl.SDL_DestroyTexture(texture);
    assert(sdl.SDL_SetRenderTarget(renderer, texture) == 0);

    _ = sdl.IMG_Init(sdl.IMG_INIT_PNG | sdl.IMG_INIT_JPG);
    defer sdl.IMG_Quit();
    const zig_png = sdl.IMG_LoadTexture(renderer, "test/resources/zig.png") orelse unreachable;
    defer sdl.SDL_DestroyTexture(zig_png);
    const sunglasses_jpg = sdl.IMG_LoadTexture(renderer, "test/resources/sunglasses.jpg") orelse unreachable;
    defer sdl.SDL_DestroyTexture(sunglasses_jpg);

    try drawBlockContext(renderer, texture_pixel_format, zig_png, sunglasses_jpg);
    sdl.SDL_RenderPresent(renderer);

    assert(sdl.SDL_SetRenderTarget(renderer, window_texture) == 0);
    var running: bool = true;
    var event: sdl.SDL_Event = undefined;
    while (running) {
        while (sdl.SDL_PollEvent(&event) != 0) {
            if (event.@"type" == sdl.SDL_WINDOWEVENT) {
                if (event.window.event == sdl.SDL_WINDOWEVENT_CLOSE)
                    running = false;
            } else if (event.@"type" == sdl.SDL_QUIT) {
                running = false;
            }
        }

        assert(sdl.SDL_RenderClear(renderer) == 0);
        assert(sdl.SDL_RenderCopy(renderer, texture, null, &sdl.SDL_Rect{
            .x = 0,
            .y = 0,
            .w = width,
            .h = height,
        }) == 0);
        sdl.SDL_RenderPresent(renderer);
    }
}

fn drawBlockContext(renderer: *sdl.SDL_Renderer, pixel_format: *sdl.SDL_PixelFormat, zig_png: *sdl.SDL_Texture, sunglasses_jpg: *sdl.SDL_Texture) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());

    var ctx1 = try exampleBlockContext1(&gpa.allocator, zig_png);
    defer ctx1.deinit();

    var ctx2 = try exampleBlockContext2(&gpa.allocator);
    defer ctx2.deinit();

    var ctx3 = try exampleBlockContext3(&gpa.allocator, sunglasses_jpg);
    defer ctx3.deinit();

    var ctx4 = try exampleBlockContext4(&gpa.allocator);
    defer ctx4.deinit();

    var ctx5 = try exampleBlockContext5(&gpa.allocator);
    defer ctx5.deinit();

    var offset_tree_1 = try zss.offset_tree.fromBlockContext(&ctx1, &gpa.allocator);
    defer offset_tree_1.deinitRecursive(&gpa.allocator);

    var offset_tree_2 = try zss.offset_tree.fromBlockContext(&ctx2, &gpa.allocator);
    defer offset_tree_2.deinitRecursive(&gpa.allocator);

    var offset_tree_3 = try zss.offset_tree.fromBlockContext(&ctx3, &gpa.allocator);
    defer offset_tree_3.deinitRecursive(&gpa.allocator);

    var offset_tree_4 = try zss.offset_tree.fromBlockContext(&ctx4, &gpa.allocator);
    defer offset_tree_4.deinitRecursive(&gpa.allocator);

    var offset_tree_5 = try zss.offset_tree.fromBlockContext(&ctx5, &gpa.allocator);
    defer offset_tree_5.deinitRecursive(&gpa.allocator);

    var stacking_context_root = zss.stacking_context.StackingContextTree{};
    defer stacking_context_root.deinitRecursive(&gpa.allocator);

    _ = try stacking_context_root.insert(
        &gpa.allocator,
        &[_]u16{0},
        zss.stacking_context.StackingContext{
            .midpoint = 2,
            .offset = .{ .x = 0, .y = 0 },
            .clip_rect = .{ .x = 0, .y = 0, .w = 1000000, .h = 1000000 },
            .inner_context = .{
                .block = .{
                    .context = &ctx1,
                    .offset_tree = &offset_tree_1,
                },
            },
        },
        undefined,
    );

    _ = try stacking_context_root.insert(
        &gpa.allocator,
        &[_]u16{ 0, 0 },
        zss.stacking_context.StackingContext{
            .midpoint = 0,
            .offset = .{ .x = 100, .y = 110 },
            .clip_rect = .{ .x = 0, .y = 0, .w = 1000000, .h = 1000000 },
            .inner_context = .{
                .block = .{
                    .context = &ctx2,
                    .offset_tree = &offset_tree_2,
                },
            },
        },
        undefined,
    );

    _ = try stacking_context_root.insert(
        &gpa.allocator,
        &[_]u16{ 0, 1 },
        zss.stacking_context.StackingContext{
            .midpoint = 0,
            .offset = .{ .x = 450, .y = 110 },
            .clip_rect = .{ .x = 0, .y = 0, .w = 1000000, .h = 1000000 },
            .inner_context = .{
                .block = .{
                    .context = &ctx3,
                    .offset_tree = &offset_tree_3,
                },
            },
        },
        undefined,
    );

    _ = try stacking_context_root.insert(
        &gpa.allocator,
        &[_]u16{ 0, 2 },
        zss.stacking_context.StackingContext{
            .midpoint = 1,
            .offset = .{ .x = 400, .y = 400 },
            .clip_rect = .{ .x = 0, .y = 0, .w = 1000000, .h = 1000000 },
            .inner_context = .{
                .block = .{
                    .context = &ctx4,
                    .offset_tree = &offset_tree_4,
                },
            },
        },
        undefined,
    );

    _ = try stacking_context_root.insert(
        &gpa.allocator,
        &[_]u16{ 0, 2, 0 },
        zss.stacking_context.StackingContext{
            .midpoint = 0,
            .offset = .{ .x = 200, .y = 350 },
            .clip_rect = .{ .x = 0, .y = 0, .w = 1000000, .h = 1000000 },
            .inner_context = .{
                .block = .{
                    .context = &ctx5,
                    .offset_tree = &offset_tree_5,
                },
            },
        },
        undefined,
    );

    try renderStackingContexts(&stacking_context_root, &gpa.allocator, renderer, pixel_format);
}

fn exampleBlockContext1(allocator: *std.mem.Allocator, zig_png: *sdl.SDL_Texture) !zss.BlockFormattingContext {
    var blk_ctx = zss.BlockFormattingContext.init(allocator);
    errdefer blk_ctx.deinit();

    const Part = zss.BlockFormattingContext.IdPart;

    const root = &[_]Part{0};
    {
        try blk_ctx.new(root);
        try blk_ctx.set(root, .dimension, .{ .width = 700, .height = 550 });
        try blk_ctx.set(root, .background_color, .{ .rgba = 0xff223300 });
        try blk_ctx.set(root, .padding, .{ .left = 100, .top = 50 });
        try blk_ctx.set(root, .background_image, .{
            .image = textureAsBackgroundImage(zig_png),
            .position = .{ .vertical = 0.5, .horizontal = 0.5 },
            .size = .{ .width = 0.75, .height = 0.5 },
            .repeat = .{ .x = .Space, .y = .Repeat },
        });
    }

    const root_0 = root ++ [_]Part{0};
    {
        try blk_ctx.new(root_0);
        try blk_ctx.set(root_0, .dimension, .{ .width = 100, .height = 100 });
        try blk_ctx.set(root_0, .background_color, .{ .rgba = 0x00df1213 });
        try blk_ctx.set(root_0, .margin_left_right, .{ .left = 250 });
        try blk_ctx.set(root_0, .margin_top_bottom, .{ .top = 50 });
        try blk_ctx.set(root_0, .visual_effect, .{ .visibility = .Hidden });
    }

    const root_0_0 = root_0 ++ [_]Part{0};
    {
        try blk_ctx.new(root_0_0);
        try blk_ctx.set(root_0_0, .dimension, .{ .width = 40, .height = 40 });
        try blk_ctx.set(root_0_0, .background_color, .{ .rgba = 0x5c76d3ff });
    }

    return blk_ctx;
}

fn exampleBlockContext2(allocator: *std.mem.Allocator) !zss.BlockFormattingContext {
    var blk_ctx = zss.BlockFormattingContext.init(allocator);
    errdefer blk_ctx.deinit();

    const Part = zss.BlockFormattingContext.IdPart;

    const root = &[_]Part{0};
    {
        try blk_ctx.new(root);
        try blk_ctx.set(root, .dimension, .{ .width = 100, .height = 100 });
        try blk_ctx.set(root, .borders, .{ .top = 5, .right = 10, .bottom = 15, .left = 20 });
        try blk_ctx.set(root, .background_color, .{ .rgba = 0x306892ff });
    }

    return blk_ctx;
}

fn exampleBlockContext3(allocator: *std.mem.Allocator, sunglasses_jpg: *sdl.SDL_Texture) !zss.BlockFormattingContext {
    var blk_ctx = zss.BlockFormattingContext.init(allocator);
    errdefer blk_ctx.deinit();

    const Part = zss.BlockFormattingContext.IdPart;

    const root = &[_]Part{0};
    {
        try blk_ctx.new(root);
        try blk_ctx.set(root, .dimension, .{ .width = 300, .height = 150 });
        //try blk_ctx.set(root, .padding, .{ .top = 20, .bottom = 35 });
        try blk_ctx.set(root, .borders, .{ .top = 10, .right = 10, .bottom = 10, .left = 10 });
        try blk_ctx.set(root, .background_color, .{ .rgba = 0x592b1cff });
        try blk_ctx.set(root, .visual_effect, .{ .overflow = .Hidden });
        try blk_ctx.set(root, .background_image, .{ .image = textureAsBackgroundImage(sunglasses_jpg), .position = .{ .horizontal = 0.4, .vertical = 0.9 }, .clip = .Content });
    }

    const root_0 = root ++ [_]Part{0};
    {
        try blk_ctx.new(root_0);
        try blk_ctx.set(root_0, .dimension, .{ .width = 100, .height = 100 });
        try blk_ctx.set(root_0, .borders, .{ .top = 10, .right = 10, .bottom = 10, .left = 10 });
        try blk_ctx.set(root_0, .border_colors, .{ .top_rgba = 0x789b58ff, .right_rgba = 0x789b58ff, .bottom_rgba = 0x789b58ff, .left_rgba = 0x789b58ff });
        try blk_ctx.set(root_0, .background_color, .{ .rgba = 0x9500abff });
        try blk_ctx.set(root_0, .margin_left_right, .{ .left = -25 });
        try blk_ctx.set(root_0, .margin_top_bottom, .{ .top = -30 });
    }

    return blk_ctx;
}

fn exampleBlockContext4(allocator: *std.mem.Allocator) !zss.BlockFormattingContext {
    var blk_ctx = zss.BlockFormattingContext.init(allocator);
    errdefer blk_ctx.deinit();

    const Part = zss.BlockFormattingContext.IdPart;

    const root = &[_]Part{0};
    {
        try blk_ctx.new(root);
        try blk_ctx.set(root, .dimension, .{ .width = 150, .height = 100 });
        try blk_ctx.set(root, .borders, .{ .top = 30, .right = 30, .bottom = 30, .left = 30 });
        try blk_ctx.set(root, .border_colors, .{ .top_rgba = 0x20f4f4ff, .right_rgba = 0x3faf34ff, .bottom_rgba = 0xa32a7cff, .left_rgba = 0x102458ff });
        try blk_ctx.set(root, .background_color, .{ .rgba = 0x9104baff });
    }

    return blk_ctx;
}

fn exampleBlockContext5(allocator: *std.mem.Allocator) !zss.BlockFormattingContext {
    var blk_ctx = zss.BlockFormattingContext.init(allocator);
    errdefer blk_ctx.deinit();

    const Part = zss.BlockFormattingContext.IdPart;

    const root = &[_]Part{0};
    {
        try blk_ctx.new(root);
        try blk_ctx.set(root, .dimension, .{ .width = 75, .height = 200 });
        try blk_ctx.set(root, .background_color, .{ .rgba = 0xb186afff });
        try blk_ctx.set(root, .border_colors, .{ .top_rgba = 0xdd56faff, .right_rgba = 0x93542cff, .bottom_rgba = 0x2bda86ff, .left_rgba = 0xbca973ff });
    }

    return blk_ctx;
}
