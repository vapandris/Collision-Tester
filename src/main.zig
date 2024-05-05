// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");

const Vector = struct {
    x: f32,
    y: f32,

    pub const ZERO: Vector = .{ .x = 0, .y = 0 };
};

const Circle = struct {
    position: Vector,
    radius: f32,

    velocity: Vector = Vector.ZERO,
    acceleration: Vector = Vector.ZERO,

    pub fn assign(self: *Circle, other: Circle) void {
        self.*.radius = other.radius;
        self.*.position.x = other.position.x;
        self.*.position.y = other.position.y;
        self.*.velocity.x = other.velocity.x;
        self.*.velocity.y = other.velocity.y;
        self.*.acceleration.x = other.acceleration.x;
        self.*.acceleration.y = other.acceleration.y;
    }

    pub fn draw(self: Circle, comptime drawColor: rl.Color) void {
        // Draw black outline, and fill it with drawColor:
        rl.drawCircle(@intFromFloat(self.position.x), @intFromFloat(self.position.y), @as(f32, self.radius), rl.Color.black);
        rl.drawCircle(@intFromFloat(self.position.x), @intFromFloat(self.position.y), @as(f32, self.radius) - 2, drawColor);
    }

    pub fn isCirclePointOverlapping(self: Circle, point: Vector) bool {
        // The circle is overlapping with a point when the distance between the center of the circle and the point is less than the radius of the circle.
        // For this we can use pythagoras theorem. To avoid taking the square root of the two, we can just compare the square values.
        const distanceSquare = @fabs((self.position.x - point.x) * (self.position.x - point.x) + (self.position.y - point.y) * (self.position.y - point.y));
        const radiusSquare = (self.radius * self.radius);
        return distanceSquare < radiusSquare;
    }

    pub fn isCircleCircleOverlapping(circle1: Circle, circle2: Circle) bool {
        // A circle and another circle is overlapping when the distance between them is less than the sum of their radious.
        // For this we can use pythagoras theorem. To avoid taking the square root of the two, we can just compare the square values.
        const distanceSquare = @fabs((circle1.position.x - circle2.position.x) * (circle1.position.x - circle2.position.x) + (circle1.position.y - circle2.position.y) * (circle1.position.y - circle2.position.y));
        const radiousSumSquare = (circle1.radius + circle2.radius) * (circle1.radius + circle2.radius);

        return distanceSquare < radiousSumSquare;
    }

    // This shouldn't be inside Circle, but doesn't matter
    pub fn loopAround(self: *Circle, screenWidth: u32, screenHeight: u32) void {
        const h: f32 = @floatFromInt(screenHeight);
        const w: f32 = @floatFromInt(screenWidth);

        if (self.*.position.x < 0) self.*.position.x += w;
        if (self.*.position.x >= w) self.*.position.x -= w;
        if (self.*.position.y < 0) self.*.position.y += h;
        if (self.*.position.y >= h) self.*.position.y -= h;
    }
};

const CirclePair = struct {
    first: Circle,
    second: Circle,
};
const CircleArrayList = std.ArrayList(Circle);
const CirclePairArrayList = std.ArrayList(CirclePair);

var gameState: struct {
    isPlayerClickedOn: bool = false,
    circles: CircleArrayList,
} = undefined;

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1250;
    const screenHeight = 680;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    gameState.circles = CircleArrayList.init(std.heap.c_allocator);
    defer gameState.circles.deinit();

    var collidingCircles = CirclePairArrayList.init(std.heap.c_allocator);
    defer collidingCircles.deinit();

    // Append playerCircle at the front of the array:
    try gameState.circles.append(Circle{
        .position = Vector{ .x = screenWidth / 2, .y = screenHeight / 2 },
        .radius = 64,
    });

    // Generate 20 circles randomly:
    for (0..20) |_| {
        const minX = 0;
        const maxX = screenWidth;
        const minY = 0;
        const maxY = screenHeight;
        const randomRadius: f32 = @floatFromInt(std.crypto.random.intRangeAtMost(u32, 10, 100));
        try gameState.circles.append(Circle{
            .position = .{
                .x = @floatFromInt(std.crypto.random.intRangeAtMost(u32, minX, maxX)),
                .y = @floatFromInt(std.crypto.random.intRangeAtMost(u32, minY, maxY)),
            },
            .radius = randomRadius,
        });
    }

    // This assumes that the array does not get re-allocated !!!
    var playerCircle: *Circle = &gameState.circles.items[0];

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        { // Handle mouse input:
            if (rl.isMouseButtonPressed(.mouse_button_left) or rl.isMouseButtonPressed(.mouse_button_right)) {
                const location = rl.getMousePosition();
                const locationVector = Vector{ .x = location.x, .y = location.y };

                if (playerCircle.*.isCirclePointOverlapping(locationVector)) {
                    gameState.isPlayerClickedOn = true;
                }
            }

            if (rl.isMouseButtonReleased(.mouse_button_left)) {
                gameState.isPlayerClickedOn = false;
            }
            if (rl.isMouseButtonReleased(.mouse_button_right)) {
                gameState.isPlayerClickedOn = false;

                const mouseLocation = rl.getMousePosition();
                playerCircle.*.velocity.x = 1.0 * ((playerCircle.*.position.x) - mouseLocation.x);
                playerCircle.*.velocity.y = 1.0 * ((playerCircle.*.position.y) - mouseLocation.y);
            }

            if (gameState.isPlayerClickedOn == true) {
                if (rl.isMouseButtonDown(.mouse_button_left)) {
                    const mouseLocation = rl.getMousePosition();

                    playerCircle.*.position.x = mouseLocation.x;
                    playerCircle.*.position.y = mouseLocation.y;
                }
            }
        }

        { // Move cirlces based on velocity: (for now just the player circle)
            playerCircle.*.acceleration.x = -playerCircle.*.velocity.x * 0.8;
            playerCircle.*.acceleration.y = -playerCircle.*.velocity.y * 0.8;
            playerCircle.*.velocity.x += playerCircle.*.acceleration.x * rl.getFrameTime();
            playerCircle.*.velocity.y += playerCircle.*.acceleration.y * rl.getFrameTime();
            playerCircle.*.position.x += playerCircle.*.velocity.x * rl.getFrameTime();
            playerCircle.*.position.y += playerCircle.*.velocity.y * rl.getFrameTime();

            if (@fabs(playerCircle.*.velocity.x * playerCircle.*.velocity.x + playerCircle.*.velocity.y * playerCircle.*.velocity.y) < 250.0) {
                playerCircle.*.velocity = Vector.ZERO;
                playerCircle.*.acceleration = Vector.ZERO;
            }
        }

        { // Loop around screen
            for (gameState.circles.items) |*circle| {
                circle.loopAround(screenWidth, screenHeight);
            }

            playerCircle.loopAround(screenWidth, screenHeight);
        }

        { // Resolve collisions:
            // Reset the colliding circles array:
            collidingCircles.items.len = 0;

            for (gameState.circles.items, 0..) |*circle, i| {
                for (gameState.circles.items, 0..) |*otherCircle, j| {
                    if (i == j) continue;

                    if (Circle.isCircleCircleOverlapping(circle.*, otherCircle.*) == true) {
                        const p1 = circle.*.position;
                        const p2 = otherCircle.*.position;
                        const distance = @sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
                        const overlap = 0.5 * (distance - circle.radius - otherCircle.radius);

                        // Displace the circles:
                        circle.*.position.x -= overlap - ((p1.x - p2.x) / distance);
                        circle.*.position.y -= overlap - ((p1.y - p2.y) / distance);

                        otherCircle.*.position.x += overlap - ((p1.x - p2.x) / distance);
                        otherCircle.*.position.y += overlap - ((p1.y - p2.y) / distance);

                        try collidingCircles.append(CirclePair{
                            .first = circle.*,
                            .second = otherCircle.*,
                        });
                    }
                }
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);

        var i: u32 = 1;
        while (i < gameState.circles.items.len) : (i += 1) {
            gameState.circles.items[i].draw(rl.Color.blue);
        }

        playerCircle.*.draw(rl.Color.green);
        if (rl.isMouseButtonDown(.mouse_button_right)) {
            const location = rl.getMousePosition();
            const p = playerCircle.*.position;

            rl.drawLineEx(rl.Vector2{ .x = p.x, .y = p.y }, location, 2.0, rl.Color.red);
        }

        for (collidingCircles.items) |pair| {
            const p1 = pair.first.position;
            const p2 = pair.second.position;

            rl.drawLineEx(rl.Vector2{ .x = p1.x, .y = p1.y }, rl.Vector2{ .x = p2.x, .y = p2.y }, 2.0, rl.Color.red);
        }
    }
}
