;;; This file is automatically generated from file `literate-lisp.org'.
;;; Please read file `literate-lisp.org' to find out the usage and implementation detail of this source file.

(in-package #:literate-lisp)

(defvar current-org-context (make-hash-table))

(defun org-context (name)
  (gethash name current-org-context nil))

(defun set-org-context (name new-value)
  (setf (gethash name current-org-context) new-value))
(defsetf org-context set-org-context)

(defmacro define-lexer (name regex-pattern parameters &rest body)
  (let ((fun-name (intern (format nil "ORG-LEXER-FOR-~a" name))))
    `(progn (defun ,fun-name ,parameters
              ,@body)
            (if (assoc ',name (get 'lexer 'patterns))
                (setf (cdr (assoc ',name (get 'lexer 'patterns)))
                        (list ',fun-name ,regex-pattern ,(length parameters)))
                (setf (get 'lexer 'patterns)
                        (nconc (get 'lexer 'patterns)
                               (list (list ',name ',fun-name ,regex-pattern ,(length parameters)))))))))

(defun run-patterns (line)
  (iter (for (name fun-name regex-pattern parameters-count) in (get 'lexer 'patterns))
        (multiple-value-bind (match-start match-end reg-starts reg-ends)
            (scan regex-pattern line)
          (declare (ignore match-end))
          (when match-start
            (iter (with arguments = nil)
                  (for i from 0 below parameters-count)
                  (for start-index = (aref reg-starts i))
                  (setf arguments
                          (nconc arguments
                                 (list (if start-index
                                           (subseq line start-index (aref reg-ends i))
                                           nil))))
                  (finally
                   (when debug-literate-lisp-p
                     (format t "apply pattern ~a with arguments ~a~%" name arguments))
                   (apply fun-name arguments)))
            (finish)))))

(defstruct headline 
  ;; the level
  (level 0 :type integer)
  ;; the content
  (content "" :type string)
  ;; the property specified for this headline
  (properties (make-hash-table :test #'equalp) :type hash-table))

(defun org-headlines ()
  (org-context :headline))

(defun set-org-headlines (new-value)
  (setf (org-context :headline) new-value))
(defsetf org-headlines set-org-headlines)

(defun current-headline ()
  (first (org-headlines)))

(defun current-headline-level ()
  (headline-level (first (org-headlines))))

(defun current-headline-content ()
  (headline-content (first (org-headlines))))

(defun pop-org-headline ()
  (pop (org-headlines)))

(defun push-org-headline (level content)
  (push (make-headline :level level :content content) (org-headlines)))

(defun setup-headline ()
  (push-org-headline 0 ""))

(define-lexer :headline "^\\s*(\\*+)\\s+(.*)$"
  (indicators content)
  (let ((level (length indicators))
        (previous-level (current-headline-level)))
    (cond ((= previous-level level)
           ;; meet a new headline with same level, pop the old one and push the new one
           (pop-org-headline)
           (push-org-headline level content))
          ((> previous-level level) 
           ;; meet a new headline with lower level, pop the old one until meet the same level. 
           (iter (pop-org-headline)
                 (until (< (current-headline-level) level)))
           (push-org-headline level content))
          (t
           ;; meet a new headline with higher level. 
           (push-org-headline level content)))
    (when debug-literate-lisp-p
      (format t "current headline, level:~D, content:~a~%"
              (current-headline-level)
              (current-headline-content)))))

(defmacro define-org-property-value-notifier (name value-name &rest body)
  (let ((fun-name (intern (format nil "ORG-PROPERTY-VALUE-NOTIFIER-FOR-~a" name))))
    `(progn (defun ,fun-name (,value-name)
              ,@body)
            (if (assoc ',name (get 'org-property-value 'notifier) :test #'string=)
                (setf (cdr (assoc ',name (get 'org-property-value 'notifier) :test #'string=))
                        (list ',fun-name))
                (setf (get 'org-property-value 'notifier)
                        (nconc (get 'org-property-value 'notifier)
                               (list (list ,name ',fun-name))))))))

(defun notify-property-value (name new-value)
  (let ((hook (assoc name (get 'org-property-value 'notifier) :test #'string=)))
    (when hook
      (when debug-literate-lisp-p
        (format t "Notify new property value ~a:~a~%" name new-value))
      (funcall (second hook) new-value))))

(defun property-for-headline (headline key)
  (gethash key (headline-properties headline)))

(defun update-property-value (key value)
  (setf (gethash key (headline-properties (current-headline))) value)
  (notify-property-value key value))

(define-lexer :property-in-a-line "^\\s*\\#\\+PROPERTY:\\s*(\\S+)\\s+(.*)$"
  (key value)
  (when debug-literate-lisp-p
    (format t "Found property in level ~D, ~a:~a.~%"
            (current-headline-level) key value))
  (update-property-value key value))

(define-lexer :begin-of-properties "^(\\s*:PROPERTIES:\\s*)$"
  (line)
  (declare (ignore line))
  (when debug-literate-lisp-p
    (format t "Found beginning of properties.~%"))
  (setf (org-context :in-properties) t))

(define-lexer :end-of-properties "(^\\s*:END:\\s*$)"
  (line)
  (declare (ignore line))
  (when (org-context :in-properties)
    (when debug-literate-lisp-p
      (format t "Found end of properties.~%"))
    (setf (org-context :in-properties) nil)))

(define-lexer :property-in-properties "^\\s*:(\\S+):\\s*(\\S+.*)$"
  (key value)
  (when (org-context :in-properties)
    (when debug-literate-lisp-p
      (format t "Found property in level ~D, ~a:~a.~%"
              (current-headline-level) key value))
    (update-property-value key value)))

(defun org-property-value (key)
  (iter (for headline in (org-headlines))
        (for value = (property-for-headline headline key))
        (if value
            (return value))))

(defvar *tangle-org-file* nil)

(defun tangle-p ()
  *tangle-org-file*)

(defvar *tangle-head-lines* nil)

(defvar *tangle-streams* (make-hash-table :test #'equal))

(defun path-for-literate-name (name)
  (cl-fad:merge-pathnames-as-file *tangle-org-file* name))

(defvar *check-outside-modification-p* nil)

(defun tangle-stream (name)
  (or (gethash name *tangle-streams*)
    (let ((output-file (path-for-literate-name name)))
      (when (and *check-outside-modification-p*
                 (tangled-file-update-outside-p output-file))
        (error "The output file has been updated outside, please merge it into your org file before tangling!"))
      (let ((stream (open output-file
                          :direction :output
                          :element-type uiop:*default-stream-element-type*
                          :external-format uiop:*default-encoding*
                          :if-does-not-exist :create
                          :if-exists :supersede)))
        (when *tangle-head-lines*
          (write-string *tangle-head-lines* stream))
        (let ((package (org-property-value "LITERATE_EXPORT_PACKAGE")))
          (when package
            (format stream "(in-package #:~a)~%~%" package)))
        (setf (gethash name *tangle-streams*) stream)))))

(defun cleanup-tangle-streams ()
  (iter (for (name stream) in-hashtable *tangle-streams*)
        (close stream)
        (cache-tangled-file (path-for-literate-name name)))
  (clrhash *tangle-streams*))

(defvar *current-tangle-stream* nil)

(define-org-property-value-notifier "LITERATE_EXPORT_NAME" name
  (when (tangle-p)
    (setf *current-tangle-stream*
            (tangle-stream name))))

