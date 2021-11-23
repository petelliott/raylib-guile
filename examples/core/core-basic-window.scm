(use-modules (raylib))

(InitWindow 800 450 "raylib [core] example - basic window")
(SetTargetFPS 60)

(define RAYWHITE (make-Color 245 245 245 255))
(define LIGHTGRAY (make-Color 200 200 200 255))

(define (main-loop)
  (unless (WindowShouldClose)
    (BeginDrawing)

    (ClearBackground RAYWHITE)
    (DrawText "Congrats! You created your first window!" 190 200 20 LIGHTGRAY)

    (EndDrawing)
    (main-loop)))

(main-loop)
(CloseWindow)
