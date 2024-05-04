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

    fn isCircleCircleOverlapping(circle1: Circle, circle2: Circle) bool {
        // A circle and another circle is overlapping when the distance between them is less than the sum of their radious.
        // For this we can use pythagoras theorem. To avoid taking the square root of the two, we can just compare the square values.
        const distanceSquare = @fabs((circle1.position.x - circle2.position.x) * (circle1.position.x - circle2.position.x) + (circle1.position.y - circle2.position.y) * (circle1.position.y - circle2.position.y));
        const radiousSumSquare = (circle1.radius + circle2.radius) * (circle1.radius + circle2.radius);

        return distanceSquare < radiousSumSquare;
    }
};

const CircleArrayList = std.ArrayList(Circle);

var gameState: struct {
    isPlayerClickedOn: bool = false,
    playerCircle: Circle,
    otherCirlces: CircleArrayList,
} = undefined;

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    gameState.playerCircle = Circle{
        .position = Vector{ .x = screenWidth / 2, .y = screenHeight / 2 },
        .radius = 64,
    };
    gameState.otherCirlces = CircleArrayList.init(std.heap.c_allocator);
    defer gameState.otherCirlces.deinit();

    for (0..20) |_| {
        const minX = 0;
        const maxX = screenWidth;
        const minY = 0;
        const maxY = screenHeight;
        try gameState.otherCirlces.append(Circle{
            .position = .{
                .x = @floatFromInt(std.crypto.random.intRangeAtMost(u32, minX, maxX)),
                .y = @floatFromInt(std.crypto.random.intRangeAtMost(u32, minY, maxY)),
            },
            .radius = 64,
        });
    }

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        { // Handle mouse input:
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                const location = rl.getMousePosition();
                const locationVector = Vector{ .x = location.x, .y = location.y };

                if (gameState.playerCircle.isCirclePointOverlapping(locationVector)) {
                    gameState.isPlayerClickedOn = true;
                }
            }

            if (rl.isMouseButtonReleased(.mouse_button_left)) {
                gameState.isPlayerClickedOn = false;
            }

            if (gameState.isPlayerClickedOn == true) {
                const mouseLocation = rl.getMousePosition();

                gameState.playerCircle.position.x = mouseLocation.x;
                gameState.playerCircle.position.y = mouseLocation.y;
            }
        }

        { // Resolve collisions:
            // Temporairly append the palyerCircle to the array so it doesn't have to be handled seperatelly:
            try gameState.otherCirlces.append(gameState.playerCircle);
            defer gameState.otherCirlces.items.len -= 1;

            for (gameState.otherCirlces.items, 0..) |*circle, i| {
                for (gameState.otherCirlces.items, 0..) |*otherCircle, j| {
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
                    }
                }
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.dark_gray);

        for (gameState.otherCirlces.items) |circle| {
            circle.draw(rl.Color.blue);
        }

        gameState.playerCircle.draw(rl.Color.green);
    }
}
