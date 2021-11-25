(use-modules (raylib))

(define screen-width 800)
(define screen-height 450)
(define columns 20)

(InitWindow screen-width screen-height "raylib [core] example - 3d camera first person")

;; Define the camera to look into our 3d world (position, target, up vector)
(define camera
  (make-Camera3D (make-Vector3 4 2 4)
                 (make-Vector3 0 1.8 0)
                 (make-Vector3 0 1 0)
                 60 CAMERA_PERSPECTIVE))

;; Generates some random columns
(define heights
  (map (lambda (i)
         (GetRandomValue 1 12))
       (iota columns)))

(define positions
  (map (lambda (i)
         (make-Vector3 (GetRandomValue -15 15)
                       (/ (list-ref heights i) 2)
                       (GetRandomValue -15 15)))
       (iota columns)))

(define colors
  (map (lambda (i)
         (make-Color (GetRandomValue 20 255)
                     (GetRandomValue 10 55)
                     30 255))
       (iota columns)))


(SetCameraMode camera CAMERA_FIRST_PERSON)

(SetTargetFPS 60)

;; Main Game Loop
(while (not (WindowShouldClose))
  (UpdateCamera camera)

  (BeginDrawing)

  (ClearBackground RAYWHITE)

  (BeginMode3D camera)

  (DrawPlane (make-Vector3 0.0 0.0 0.0) (make-Vector2 32.0 32.0 ) LIGHTGRAY) ; Draw ground
  (DrawCube (make-Vector3 -16.0 2.5 0.0) 1.0 5.0 32.0 BLUE)                  ; Draw a blue wall
  (DrawCube (make-Vector3 16.0 2.5 0.0) 1.0 5.0 32.0 LIME)                   ; Draw a green wall
  (DrawCube (make-Vector3 0.0 2.5 16.0) 32.0 5.0 1.0 GOLD)                   ; Draw a yellow wall
  ;; draw some cubes around
  (for-each (lambda (height position color)
              (DrawCube position 2.0 height 2.0 color)
              (DrawCubeWires position 2.0 height 2.0 MAROON))
            heights positions colors)

  (EndMode3D)

  (DrawRectangle 10 10 220 70 (Fade SKYBLUE 0.5))
  (DrawRectangleLines 10 10 220 70 BLUE)

  (DrawText "First person camera default controls:" 20 20 10 BLACK)
  (DrawText "- Move with keys: W A S D" 40 40 10 DARKGRAY)
  (DrawText "- Mouse move to look around" 40 60 10 DARKGRAY)

  (EndDrawing))

(CloseWindow)
