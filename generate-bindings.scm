#!/usr/bin/guile -s
!#
(use-modules (sxml simple)
             (ice-9 format)
             (ice-9 string-fun))

(define xml-file (cadr (command-line)))
(define coutput "raylib-guile.c")
(define scmoutput "raylib.scm")

(define xml (call-with-input-file xml-file
              (lambda (port) (xml->sxml port))))

(define raylibAPI (filter pair? (cddr (assoc 'raylibAPI (cdr xml)))))

;; structs is of the form (name ...)
(define struct-names
  (map (lambda (struct)
         (cadr (assoc 'name (cdadr struct))))
       (filter pair? (cddr (assoc 'Structs raylibAPI)))))


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
    "UpdateCamera"
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
    (format #f "*(~a*)scm_foreign_object_ref(~a, 0)" stype expr))
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

(define (declare-struct name port)
  (format port "    rgtype_~a = scm_make_foreign_object_type(scm_from_utf8_symbol(\"~a\"), slots, NULL);\n"
          name name))

(define (declare-function f port)
  (format port "    scm_c_define_gsubr(\"~a\", ~a, 0, 0, rgfun_~a);\n"
          (car f) (length (cddr f)) (car f)))

;; generate c guile bindings
(call-with-output-file coutput
  (lambda (port)
    (format port "#include <raylib.h>\n#include <libguile.h>\n#include <string.h>\n")

    (format port "\n// struct slots\n")
    (for-each (lambda (s) (format port "static SCM rgtype_~a;\n" s)) struct-names)

    (format port "\n// function definitions\n")
    (for-each (lambda (f) (generate-function f port)) functions)

    (format port "\n// guile extension entry point\n")
    (format port "void init_raylib_guile(void) {\n")
    (format port "    // expose raylib structs to guile\n")
    (format port "    SCM slots = scm_list_1 (scm_from_utf8_symbol (\"data\"));\n")
    (for-each (lambda (s) (declare-struct s port)) struct-names)
    (format port "    // expose raylib functions to guile\n")
    (for-each (lambda (f) (declare-function f port)) functions)
    (format port "}\n")))
