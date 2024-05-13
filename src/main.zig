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

    pub fn mass(self: Circle) f32 {
        return self.radius * 10;
    }

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

// Store a pair of circles and their identifying indexes to avoid putting the same pair into the array but in flipped order
const CirclePair = struct {
    first: *Circle,
    firstIndex: usize,
    second: *Circle,
    secondIndex: usize,
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
        .radius = 40,
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
                playerCircle.*.velocity.x = 2.0 * ((playerCircle.*.position.x) - mouseLocation.x);
                playerCircle.*.velocity.y = 2.0 * ((playerCircle.*.position.y) - mouseLocation.y);
            }

            if (gameState.isPlayerClickedOn == true) {
                if (rl.isMouseButtonDown(.mouse_button_left)) {
                    const mouseLocation = rl.getMousePosition();

                    playerCircle.*.position.x = mouseLocation.x;
                    playerCircle.*.position.y = mouseLocation.y;
                }
            }
        }

        for (gameState.circles.items) |*circle| { // Move cirlces based on velocity: (for now just the player circle)
            circle.*.acceleration.x = -circle.velocity.x * 0.8;
            circle.*.acceleration.y = -circle.velocity.y * 0.8;
            circle.*.velocity.x += circle.acceleration.x * rl.getFrameTime();
            circle.*.velocity.y += circle.acceleration.y * rl.getFrameTime();
            circle.*.position.x += circle.velocity.x * rl.getFrameTime();
            circle.*.position.y += circle.velocity.y * rl.getFrameTime();

            if (@fabs(circle.velocity.x * circle.velocity.x + circle.velocity.y * circle.velocity.y) < 250.0) {
                circle.*.velocity = Vector.ZERO;
                circle.*.acceleration = Vector.ZERO;
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

                    var alreadyHandeled: bool = false;
                    for (collidingCircles.items) |circlePair| {
                        if (circlePair.secondIndex == i) {
                            alreadyHandeled = true;
                            break;
                        }
                    }

                    if (alreadyHandeled) continue;

                    if (Circle.isCircleCircleOverlapping(circle.*, otherCircle.*) == true) {
                        const p1 = circle.*.position;
                        const p2 = otherCircle.*.position;
                        const distance = @sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
                        const overlap = 0.5 * (distance - circle.radius - otherCircle.radius);

                        const displaceDirectionX: f32 = (p1.x - p2.x) / distance;
                        const displaceDirectionY: f32 = (p1.y - p2.y) / distance;

                        // Displace the circles:
                        circle.*.position.x -= overlap * displaceDirectionX;
                        circle.*.position.y -= overlap * displaceDirectionY;

                        otherCircle.*.position.x += overlap * displaceDirectionX;
                        otherCircle.*.position.y += overlap * displaceDirectionY;

                        try collidingCircles.append(CirclePair{
                            .firstIndex = i,
                            .first = circle,
                            .secondIndex = j,
                            .second = otherCircle,
                        });
                    }
                }
            }

            for (collidingCircles.items) |circlePair| {
                var c1: *Circle = circlePair.first;
                var c2: *Circle = circlePair.second;

                // Optimised wiki version:
                const distance: f32 = @sqrt((c1.*.position.x - c2.*.position.x) * (c1.*.position.x - c2.*.position.x) + (c1.*.position.y - c2.*.position.y) * (c1.*.position.y - c2.*.position.y));

                const nx: f32 = (c2.*.position.x - c1.*.position.x) / distance;
                const ny: f32 = (c2.*.position.y - c1.*.position.y) / distance;

                const kx: f32 = (c1.velocity.x - c2.velocity.x);
                const ky: f32 = (c1.velocity.y - c2.velocity.y);
                const p: f32 = 2 * ((nx * kx + ny * ky) / (c1.mass() + c2.mass()));

                c1.*.velocity.x -= p * c2.mass() * nx;
                c1.*.velocity.y -= p * c2.mass() * ny;
                c2.*.velocity.x += p * c1.mass() * nx;
                c2.*.velocity.y += p * c1.mass() * ny;
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
            const p1 = pair.first.*.position;
            const p2 = pair.second.*.position;

            rl.drawLineEx(rl.Vector2{ .x = p1.x, .y = p1.y }, rl.Vector2{ .x = p2.x, .y = p2.y }, 2.0, rl.Color.red);
        }
    }
}
