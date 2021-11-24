(use-modules (raylib))

(define screen-width 800)
(define screen-height 450)

(InitWindow screen-width screen-height "raylib [core] example - basic window")
(SetTargetFPS 60)

(define (main-loop)
  (unless (WindowShouldClose)
    (BeginDrawing)

    (ClearBackground RAYWHITE)
    (DrawText "Congrats! You created your first window!" 190 200 20 LIGHTGRAY)

    (EndDrawing)
    (main-loop)))

(main-loop)
(CloseWindow)
