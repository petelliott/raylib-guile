#!/usr/local/bin/guile -s
!#
(use-modules (sxml simple)
             (ice-9 format))

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

;; functions is of the form ((name rettype (arg . type) ...) ...)
(define functions
  (map (lambda (fn)
         (cons (cadr (assoc 'name (cdadr fn)))
               (cons (cadr (assoc 'retType (cdadr fn)))
                     (map (lambda (arg)
                            (cons (cadr (assoc 'name (cdadr arg)))
                                  (cadr (assoc 'type (cdadr arg)))))
                          (filter pair? (cddr fn))))))
       (filter pair? (cddr (assoc 'Functions raylibAPI)))))
