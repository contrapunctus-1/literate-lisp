;;; This file is automatically generated from file `literate-lisp.org'.
;;; Please read file `literate-lisp.org' to find out the usage and implementation detail of this source file.

(in-package #:literate-lisp)

(defun read-keywords-from-string (string &key (start 0))
  (with-input-from-string (stream string :start start)
    (let ((*readtable* (copy-readtable nil))
          (*package* #.(find-package :keyword))
          (*read-suppress* nil))
      (iter (for minus-p = (when (char= #\- (peek-char t stream nil #\Space))
                             (read-char stream)
                             t))
            (for elem = (read stream nil))
            (while elem)
            (collect (if minus-p
                         (cons elem :not)
                         elem))))))

(defun load-p (feature)
  (cond ((eq :yes feature)
         t)
        ((eq :no feature)
         nil)
        ((null feature)
         ;; check current org property `literate-load'.
         (let ((load (org-property-value "literate-load")))
           (when debug-literate-lisp-p
             (format t "get current property value of literate-load:~a~%" load))
           (if load
               (load-p (first (read-keywords-from-string load)))
               t)))
        ((consp feature)
         ;; the feature syntax is ` (feature . :not)'.
         (if (eq :not (cdr feature))
             (not (find (car feature) *features* :test #'eq))))
        (t (find feature *features* :test #'eq))))

(defun start-position-after-space-characters (line)
  (iter (for c in-sequence line)
        (for i from 0)
        (until (not (find c '(#\Tab #\Space))))
        (finally (return i))))

(defvar org-lisp-begin-src-id "#+begin_src lisp")
(defvar org-name-property "#+NAME:")
(defvar org-name-property-length (length org-name-property))
(defvar org-block-begin-id "#+BEGIN_")
(defvar org-block-begin-id-length (length org-block-begin-id))
(defun sharp-space (stream a b)
  (declare (ignore a b))
  ;; reset org content in the beginning of the file;
  ;; here we assume sharp space meaning it.
  (setf current-org-context (make-hash-table))
  (setup-headline)
  (sharp-org stream))

(defun sharp-org (stream)
  (let ((named-code-blocks nil))
    (iter (with name-of-next-block = nil)
          (for line = (read-line stream nil nil))
          (until (null line))
          (for start1 = (start-position-after-space-characters line))
          (when debug-literate-lisp-p
            (format t "ignore line ~a~%" line))
          (run-patterns line)
          (until (and (equalp start1 (search org-lisp-begin-src-id line :test #'char-equal))
                      (let* ((header-arguments (read-keywords-from-string line :start (+ start1 (length org-lisp-begin-src-id)))))
                        (load-p (getf header-arguments :load)))))
          (cond ((equal 0 (search org-name-property line :test #'char-equal))
                 ;; record a name.
                 (setf name-of-next-block (string-trim '(#\Tab #\Space) (subseq line org-name-property-length))))
                ((equal 0 (search org-block-begin-id line :test #'char-equal))
                 ;; record the context of a block.
                 (if name-of-next-block
                     ;; start to read text in current block until reach `#+END_'
                     (let* ((end-position-of-block-name (position #\Space line :start org-block-begin-id-length))
                            (end-block-id (format nil "#+END_~a" (subseq line org-block-begin-id-length end-position-of-block-name)))
                            (block-stream (make-string-output-stream)))
                       (when (read-block-context-to-stream stream block-stream name-of-next-block end-block-id)
                         (setf named-code-blocks
                                 (nconc named-code-blocks
                                        (list (cons name-of-next-block
                                                    (get-output-stream-string block-stream)))))))
                     ;; reset name of code block if it's not sticking with a valid block.
                     (setf name-of-next-block nil)))
                (t
                 ;; reset name of code block if it's not sticking with a valid block.
                 (setf name-of-next-block nil))))
    (if named-code-blocks
        `(progn
           ,@(iter (for (block-name . block-text) in named-code-blocks)
                   (collect `(defparameter ,(intern (string-upcase block-name)) ,block-text))))
        ;; Can't return nil because ASDF will fail to find a form like `defpackage'.
        (values))))

(defun read-block-context-to-stream (input-stream block-stream block-name end-block-id)
  (iter (for line = (read-line input-stream nil))
        (cond ((null line)
               (return nil))
              ((string-equal end-block-id (string-trim '(#\Tab #\Space) line))
               (when debug-literate-lisp-p
                 (format t "reach end of block for '~a'.~%" block-name))
               (return t))
              (t
               (when debug-literate-lisp-p
                 (format t "read line for block '~a':~s~%" block-name line))
               (write-line line block-stream)))))

;;; If X is a symbol, see whether it is present in *FEATURES*. Also
;;; handle arbitrary combinations of atoms using NOT, AND, OR.
(defun featurep (x)
  #+allegro(excl:featurep x)
  #+lispworks(sys:featurep x)
  #-(or allegro lispworks)
  (typecase x
    (cons
     (case (car x)
       ((:not not)
        (cond
          ((cddr x)
           (error "too many subexpressions in feature expression: ~S" x))
          ((null (cdr x))
           (error "too few subexpressions in feature expression: ~S" x))
          (t (not (featurep (cadr x))))))
       ((:and and) (every #'featurep (cdr x)))
       ((:or or) (some #'featurep (cdr x)))
       (t
        (error "unknown operator in feature expression: ~S." x))))
    (symbol (not (null (member x *features* :test #'eq))))
    (t
      (error "invalid feature expression: ~S" x))))

(defun read-feature-as-a-keyword (stream)
  (let ((*package* #.(find-package :keyword))
        ;;(*reader-package* nil)
        (*read-suppress* nil))
    (read stream t nil t)))

(defun handle-feature-end-src (stream sub-char numarg)
  (declare (ignore sub-char numarg))
  (when debug-literate-lisp-p
    (format t "found #+END_SRC,start read org part...~%"))
  (funcall #'sharp-org stream))

(defun read-featurep-object (stream)
  (read stream t nil t))

(defun read-unavailable-feature-object (stream)
  (let ((*read-suppress* t))
    (read stream t nil t)
    (values)))

(defun sharp-plus (stream sub-char numarg)
  (let ((feature (read-feature-as-a-keyword stream)))
    (when debug-literate-lisp-p
      (format t "found feature ~s,start read org part...~%" feature))
    (cond ((eq :END_SRC feature) (handle-feature-end-src stream sub-char numarg))
          ((featurep feature)    (read-featurep-object stream))
          (t                     (read-unavailable-feature-object stream)))))

(defun install-globally ()
  (set-dispatch-macro-character #\# #\space #'sharp-space)
  (set-dispatch-macro-character #\# #\+ #'sharp-plus))
#+literate-global(install-globally)

(defmacro with-literate-syntax (&body body)
  `(let ((*readtable* (copy-readtable)))
     ;; install it in current readtable
     (set-dispatch-macro-character #\# #\space #'literate-lisp::sharp-space)
     (set-dispatch-macro-character #\# #\+ #'literate-lisp::sharp-plus)
     ,@body))

