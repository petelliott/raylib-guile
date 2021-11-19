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

;; functions is of the form ((name rettype (type arg) ...) ...)
(define functions
  (map (lambda (fn)
         (cons (cadr (assoc 'name (cdadr fn)))
               (cons (cadr (assoc 'retType (cdadr fn)))
                     (map (lambda (arg)
                            (cons (cadr (assoc 'name (cdadr arg)))
                                  (cadr (assoc 'type (cdadr arg)))))
                          (filter pair? (cddr fn))))))
       (filter pair? (cddr (assoc 'Functions raylibAPI)))))

(define genlocal ((lambda ()
                    (define val 0)
                    (lambda ()
                      (set! val (+ 1 val))
                      (format #f "v~a" val)))))

(define (sanitize-type type)
  (string-replace-substring type "unsigned " "u"))

(define (scm->c port type expr)
  (cond
   ((string= type "const char *")
    (let ((local (genlocal)))
      (format port "    char *~a = scm_to_utf8_stringn(~a, NULL);\n    scm_dynwind_free(~a);\n" local expr local)
      local))
   (else (format #f "scm_to_~a(~a)" (sanitize-type type) expr))))

(define (c->scm port type expr)
  (cond
   ((string= type "const char *")
    (format #f "scm_from_utf8_string(~a)" expr))
   ((string= type "void")
    (format #f "(~a, SCM_UNSPECIFIED)" expr))
   (else (format #f "scm_from_~a(~a)" (sanitize-type type) expr))))

(define (generate-function f port)
  (format port "SCM raylib_guile_~a(~{SCM ~a~^, ~}) {\n" (car f) (map car (cddr f)))
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


;; generate c guile bindings
(call-with-output-file coutput
  (lambda (port)
    (format port "#include <raylib.h>\n#include <libguile.h>\n\n")

    ;; generate t
    (for-each (lambda (f) (generate-function f port) functions)
              functions)))
