(use-modules (raylib))

(define screen-width 800)
(define screen-height 450)

(InitWindow screen-width screen-height "raylib [core] example - keyboard input")

(define ball-position (make-Vector2 (/ screen-width 2)
                                    (/ screen-height 2)))

(SetTargetFPS 60)

(define (Vector2-delta! vec dx dy)
  (Vector2-set-x! vec (+ dx (Vector2-x vec)))
  (Vector2-set-y! vec (+ dy (Vector2-y vec))))

(define (main-loop)
  (unless (WindowShouldClose)
    ;; Update
    (when (IsKeyDown KEY_RIGHT) (Vector2-delta! ball-position 2 0))
    (when (IsKeyDown KEY_LEFT)  (Vector2-delta! ball-position -2 0))
    (when (IsKeyDown KEY_UP)    (Vector2-delta! ball-position 0 -2))
    (when (IsKeyDown KEY_DOWN)  (Vector2-delta! ball-position 0 2))

    ;; Draw
    (BeginDrawing)

    (ClearBackground RAYWHITE)
    (DrawText "move the ball with arrow keys" 10 10 20 DARKGRAY)
    (DrawCircleV ball-position 50 MAROON)

    (EndDrawing)
    (main-loop)))

(main-loop)
(CloseWindow)
