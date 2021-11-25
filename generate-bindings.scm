#!/usr/bin/guile -s
!#
(use-modules (sxml simple)
             (ice-9 format)
             (ice-9 string-fun)
             (srfi srfi-1))

(define xml-file (cadr (command-line)))
(define coutput "raylib-guile.c")
(define scmoutput "raylib.scm")

(define xml (call-with-input-file xml-file
              (lambda (port) (xml->sxml port))))

(define raylibAPI (filter pair? (cddr (assoc 'raylibAPI (cdr xml)))))

;; structs is of the form ((name (field . value) ...) ...)
(define structs
  (map (lambda (struct)
         (cons (cadr (assoc 'name (cdadr struct)))
               (map (lambda (value)
                      (cons (cadr (assoc 'name (cdadr value)))
                            (cadr (assoc 'type (cdadr value)))))
                    (filter pair? (cddr struct)))))
       (filter pair? (cddr (assoc 'Structs raylibAPI)))))

(define struct-names (map car structs))

;; TODO: add upstream support in raylib's parser for Matrix
;; these structs are still available, but there are no accessors for them.
(define struct-blacklist
  '("Matrix"
    "Image"
    "Mesh"
    "Shader"
    "Model"
    "ModelAnimation"
    "Wave"
    "AudioStream"
    "Music"
    "VrDeviceInfo"
    "VrStereoConfig"
    "Font"
    "Material"
    "BoneInfo"))

(set! structs (filter (lambda (s) (not (member (car s) struct-blacklist)))
                       structs))

;; enums is of the form ((name (variant . value) ...) ...)
(define enums
  (map (lambda (enum)
         (cons (cadr (assoc 'name (cdadr enum)))
               (map (lambda (value)
                      (cons (cadr (assoc 'name (cdadr value)))
                            (string->number (cadr (assoc 'integer (cdadr value))))))
                    (filter pair? (cddr enum)))))
       (filter pair? (cddr (assoc 'Enums raylibAPI)))))

;; these functions don't appear in the generated bindings.
;; some of them should be re-added when our generation gets smarter, and some will be hand written.
(define fn-blacklist
  '("GetWindowHandle"
    "SetShaderValue"
    "SetShaderValueV"
    "TraceLog"
    "MemAlloc"
    "MemRealloc"
    "MemFree"
    "SetTraceLogCallback"
    "SetLoadFileDataCallback"
    "SetSaveFileDataCallback"
    "SetLoadFileTextCallback"
    "SetSaveFileTextCallback"
    "LoadFileData"
    "UnloadFileData"
    "SaveFileData"
    "LoadFileText"
    "UnloadFileText"
    "SaveFileText"
    "GetDirectoryFiles"
    "GetDroppedFiles"
    "CompressData"
    "DecompressData"
    "EncodeDataBase64"
    "DecodeDataBase64"
    "DrawLineStrip"
    "DrawTriangleFan"
    "DrawTriangleStrip"
    "CheckCollisionLines"
    "LoadImageAnim"
    "LoadImageColors"
    "LoadImagePalette"
    "UpdateTexture"
    "UpdateTextureRec"
    "GetPixelColor"
    "SetPixelColor"
    "LoadFontEx"
    "LoadFontFromMemory"
    "LoadFontData"
    "GenImageFontAtlas"
    "LoadCodepoints"
    "UnloadCodepoints"
    "GetCodepoint"
    "CodepointToUTF8"
    "TextCodepointsToUTF8"
    "TextCopy"
    "TextFormat"
    "TextJoin"
    "TextSplit"
    "TextAppend"
    "UpdateMeshBuffer"
    "LoadMaterials"
    "LoadModelAnimations"
    "UnloadModelAnimations"
    "UpdateSound"
    "LoadWaveSamples"
    "UnloadWaveSamples"
    "UpdateAudioStream"))


;; functions is of the form ((name rettype (type arg) ...) ...)
(define functions
  (filter (lambda (fn) (not (member (car fn) fn-blacklist)))
          (map (lambda (fn)
                 (cons (cadr (assoc 'name (cdadr fn)))
                       (cons (cadr (assoc 'retType (cdadr fn)))
                             (map (lambda (arg)
                                    (cons (cadr (assoc 'name (cdadr arg)))
                                          (cadr (assoc 'type (cdadr arg)))))
                                  (filter pair? (cddr fn))))))
               (filter pair? (cddr (assoc 'Functions raylibAPI))))))

(define genlocal ((lambda ()
                    (define val 0)
                    (lambda ()
                      (set! val (+ 1 val))
                      (format #f "v~a" val)))))

;; TODO: add this to raylib's api parser upstream.
(define (resolve-typedef type)
  (define aliases
    '(("Quaternion" . "Vector4")
      ("Texture2D" . "Texture")
      ("TextureCubemap" . "Texture")
      ("RenderTexture2D" . "RenderTexture")
      ("Camera" . "Camera3D")))
  (define entry (assoc type aliases))
  (if entry (cdr entry) type))

(define (sanitize-type type)
  (string-replace-substring
   (string-replace-substring
    (resolve-typedef type) "unsigned " "u")
   "const " ""))

(define (deptr-type type)
  (if (and (>= (string-length type) 2)
           (string= (substring type (- (string-length type) 2)) " *"))
      (substring type 0 (- (string-length type) 2))
      ""))

(define (scm->c port type expr)
  (define stype (sanitize-type type))
  (define dtype (sanitize-type (deptr-type type)))
  (cond
   ((or (string= stype "char *") (string= stype "uchar *"))
    (let ((local (genlocal)))
      (format port "    char *~a = scm_to_utf8_stringn(~a, NULL);\n    scm_dynwind_free(~a);\n" local expr local)
      local))
   ((member stype struct-names)
    (format port "    scm_assert_foreign_object_type(rgtype_~a, ~a);\n" stype expr)
    (format #f "(*(~a*)scm_foreign_object_ref(~a, 0))" stype expr))
   ((member dtype struct-names)
    (format port "    scm_assert_foreign_object_type(rgtype_~a, ~a);\n" dtype expr)
    (format #f "scm_foreign_object_ref(~a, 0)" expr))
   ((string= stype "float") (format #f "scm_to_double(~a)" expr))
   (else (format #f "scm_to_~a(~a)" stype expr))))

(define (c->scm port type expr)
  (define stype (sanitize-type type))
  (define dtype (sanitize-type (deptr-type type)))
  (cond
   ((or (string= stype "char *") (string= stype "uchar *"))
    (format #f "scm_from_utf8_string(~a)" expr))
   ((string= type "void")
    (format #f "(~a, SCM_UNSPECIFIED)" expr))
   ((member stype struct-names)
    (let ((local (genlocal)))
      (format port "    void *~a = scm_gc_malloc_pointerless(sizeof(~a), \"raylib-guile ptr\");\n" local stype)
      (format port "    ~a ~a_data = ~a;\n    memcpy(~a, &~a_data, sizeof(~a));\n"
              stype local expr local local stype)
      (format #f "scm_make_foreign_object_1(rgtype_~a, ~a)" stype local)))
   ((string= stype "float") (format #f "scm_from_double(~a)" expr))
   (else (format #f "scm_from_~a(~a)" stype expr))))

(define (generate-function f port)
  (format port "SCM rgfun_~a(~{SCM ~a~^, ~}) {\n" (car f) (map car (cddr f)))
  (format port "    scm_dynwind_begin(0);\n")
  (format port "    SCM result = ~a;\n"
          (c->scm port (cadr f)
                  (format #f "~a(~{~a~^, ~})"
                          (car f)
                          (map (lambda (arg) (scm->c port (cdr arg) (car arg)))
                               (cddr f)))))
  (format port "    scm_dynwind_end();\n")
  (format port "    return result;\n")
  (format port "}\n\n"))

(define (generate-struct-accessors s port)
  ;; generate make-struct
  (format port "SCM rgacc_make_~a(~{SCM ~a~^, ~}) {\n" (car s) (map car (cdr s)))
  (format port "    scm_dynwind_begin(0);\n")
  (format port "    ~a *rg_data = scm_gc_malloc_pointerless(sizeof(~a), \"raylib-guile ptr\");\n" (car s) (car s))

  (format port "~:{    rg_data->~a = ~a;\n~}"
          (map (lambda (field)
                 (list (car field)
                       (scm->c port (cdr field) (car field))))
               (cdr s)))

  (format port "    SCM result = scm_make_foreign_object_1(rgtype_~a, rg_data);\n" (car s))
  (format port "    scm_dynwind_end();\n")
  (format port "    return result;\n")
  (format port "}\n\n")
  ;; generate getters
  (for-each
   (lambda (field)
     (format port "SCM rgacc_~a_~a(SCM _obj) {\n" (car s) (car field))
     (format port "    return ~a;\n"
             ;; this will sometimes copy a struct when it could just wrap the
             ;; pointer. this is probably safer for the GC, but might become a performance issue.
             ;;(c->scm port (cdr field) (format #f "((~a *)scm_foreign_object_ref(_obj, 0))->~a"
             ;;                                 (car s) (car field))))
             (c->scm port (cdr field) (format #f "~a.~a" (scm->c port (car s) "_obj") (car field))))
     (format port "}\n\n"))
   (cdr s))
  ;; generate setters
  (for-each
   (lambda (field)
     (format port "SCM rgacc_~a_set_~a(SCM _obj, SCM ~a) {\n" (car s) (car field) (car field))
     (format port "    ~a.~a = ~a;\n"
             (scm->c port (car s) "_obj")
             (car field)
             (scm->c port (cdr field) (car field)))
     (format port "    return SCM_UNSPECIFIED;\n")
     (format port "}\n\n"))
   (cdr s)))


(define (accessor-names structs)
  (fold append '()
        (map (lambda (struct)
               `(,(list (format #f "make-~a" (car struct))
                        (length (cdr struct))
                        (format #f "rgacc_make_~a" (car struct)))
                 ,@(map (lambda (field) (list (format #f "~a-~a" (car struct) (car field))
                                              1
                                              (format #f "rgacc_~a_~a" (car struct) (car field))))
                        (cdr struct))
                 ,@(map (lambda (field) (list (format #f "~a-set-~a!" (car struct) (car field))
                                              2
                                              (format #f "rgacc_~a_set_~a" (car struct) (car field))))
                        (cdr struct))))
             structs)))

(define (declare-struct name port)
  (format port "    rgtype_~a = scm_make_foreign_object_type(scm_from_utf8_symbol(\"~a\"), slots, NULL);\n"
          name name))

(define (declare-accessors structs port)
  (for-each (lambda (accessor)
              (apply format port "    scm_c_define_gsubr(\"~a\", ~a, 0, 0, ~a);\n" accessor))
            (accessor-names structs)))

(define (declare-function f port)
  (format port "    scm_c_define_gsubr(\"~a\", ~a, 0, 0, rgfun_~a);\n"
          (car f) (length (cddr f)) (car f)))

(define raylib-colors
  '((LIGHTGRAY  200 200 200 255)
    (GRAY       130 130 130 255)
    (DARKGRAY   80 80 80 255)
    (YELLOW     253 249 0 255)
    (GOLD       255 203 0 255)
    (ORANGE     255 161 0 255)
    (PINK       255 109 194 255)
    (RED        230 41 55 255)
    (MAROON     190 33 55 255)
    (GREEN      0 228 48 255)
    (LIME       0 158 47 255)
    (DARKGREEN  0 117 44 255)
    (SKYBLUE    102 191 255 255)
    (BLUE       0 121 241 255)
    (DARKBLUE   0 82 172 255)
    (PURPLE     200 122 255 255)
    (VIOLET     135 60 190 255)
    (DARKPURPLE 112 31 126 255)
    (BEIGE      211 176 131 255)
    (BROWN      127 106 79 255)
    (DARKBROWN  76 63 47 255)
    (WHITE      255 255 255 255)
    (BLACK      0 0 0 255)
    (BLANK      0 0 0 0)
    (MAGENTA    255 0 255 255)
    (RAYWHITE   245 245 245 255)))

;; generate c guile bindings
(call-with-output-file coutput
  (lambda (port)
    (format port "#include <raylib.h>\n#include <libguile.h>\n#include <string.h>\n")

    (format port "\n// struct slots\n")
    (for-each (lambda (s) (format port "static SCM rgtype_~a;\n" s)) struct-names)

    (format port "\n// struct accessors\n")
    (for-each (lambda (s) (generate-struct-accessors s port)) structs)

    (format port "\n// function definitions\n")
    (for-each (lambda (f) (generate-function f port)) functions)

    (format port "\n// guile extension entry point\n")
    (format port "void init_raylib_guile(void) {\n")
    (format port "    // expose raylib structs to guile\n")
    (format port "    SCM slots = scm_list_1 (scm_from_utf8_symbol (\"data\"));\n")
    (for-each (lambda (s) (declare-struct s port)) struct-names)
    (format port "    // expose raylib accessors to guile\n")
    (declare-accessors structs port)
    (format port "    // expose raylib functions to guile\n")
    (for-each (lambda (f) (declare-function f port)) functions)
    (format port "}\n")))

;; generate guile module
(call-with-output-file scmoutput
  (lambda (port)
    (format port "(define-module (raylib)\n  #:export (")
    (format port  "~a" (caar functions))
    (for-each (lambda (f) (format port "\n            ~a" (car f))) (cdr functions))
    (for-each (lambda (e)
                (for-each (lambda (v) (format port "\n            ~a" (car v)))
                          (cdr e)))
              enums)
    (for-each (lambda (acc) (format port "\n            ~a" (car acc))) (accessor-names structs))
    (for-each (lambda (color) (format port "\n            ~a" (car color))) raylib-colors)
    (format port "))\n\n")
    (format port "(load-extension \"libraylib-guile\" \"init_raylib_guile\")\n\n")
    (for-each (lambda (e)
                (for-each (lambda (v) (format port "(define ~a ~a)\n" (car v) (cdr v)))
                          (cdr e)))
              enums)
    (for-each (lambda (color)
                (format port "(define ~a (make-Color~:{ ~a~}))\n"
                        (car color) (map list (cdr color))))
              raylib-colors)))
