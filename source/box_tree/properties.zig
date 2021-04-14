const values = @import("values.zig");

fn withDefaults(comptime T: type) type {
    const Defaults = values.mergeUnions(values.Initial, values.mergeUnions(values.Inherit, values.Unset));
    return values.mergeUnions(T, Defaults);
}

fn withNone(comptime T: type) type {
    return values.mergeUnions(T, values.None);
}

fn withAuto(comptime T: type) type {
    return values.mergeUnions(T, values.Auto);
}

fn withPercentage(comptime T: type) type {
    return values.mergeUnions(T, values.Percentage);
}

pub const LogicalSize = struct {
    pub const Size = withDefaults(withAuto(values.LengthPercentage));
    pub const MinValue = withDefaults(values.LengthPercentage);
    pub const MaxValue = withDefaults(withNone(values.LengthPercentage));
    pub const BorderValue = withDefaults(values.LineWidth);
    pub const PaddingValue = withDefaults(values.LengthPercentage);
    pub const MarginValue = withDefaults(withAuto(values.LengthPercentage));

    size: Size = .{ .auto = {} },
    min_size: MinValue = .{ .px = 0 },
    max_size: MaxValue = .{ .none = {} },
    // NOTE the default value for borders should be 'medium'
    // but I'm setting it to 0 just to make life easier.
    border_start_width: BorderValue = .{ .px = 0 },
    border_end_width: BorderValue = .{ .px = 0 },
    padding_start: PaddingValue = .{ .px = 0 },
    padding_end: PaddingValue = .{ .px = 0 },
    margin_start: MarginValue = .{ .px = 0 },
    margin_end: MarginValue = .{ .px = 0 },
};

pub const Display = withDefaults(withNone(values.Display));

pub const PositionInset = struct {
    pub const PositionValue = withDefaults(values.Position);
    pub const InsetValue = withDefaults(withAuto(values.LengthPercentage));

    position: PositionValue = .{ .static = {} },
    block_start: InsetValue = .{ .auto = {} },
    block_end: InsetValue = .{ .auto = {} },
    inline_start: InsetValue = .{ .auto = {} },
    inline_end: InsetValue = .{ .auto = {} },
};

pub const Latin1Text = struct {
    text: []const u8,
};

pub const Font = struct {
    const hb = @import("harfbuzz");
    font: ?*hb.hb_font_t,
};
