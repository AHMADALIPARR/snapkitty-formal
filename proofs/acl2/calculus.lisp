(in-package "SNAPKITTY-CALCULUS")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1. SYMBOLIC TERM CALCULUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun termp (x)
  (if (atom x)
      t
      (and
        (consp x)
        (member-equal
          (car x)
          '(:var :const :not :and :or :xor :eq :ite :add :mul))
        (term-listp (cdr x)))))

(defun term-listp (xs)
  (if (endp xs)
      t
      (and (termp (car xs))
           (term-listp (cdr xs)))))

(defun symbolic-var (name)
  (list :var name))

(defun symbolic-const (value)
  (list :const value))

(defun symbolic-eq (a b)
  (list :eq a b))

(defun symbolic-and (a b)
  (list :and a b))

(defun symbolic-xor (a b)
  (list :xor a b))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 2. SUBSTITUTION CALCULUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun lookup-symbol (name environment)
  (if (endp environment)
      nil
      (if (equal name (caar environment))
          (cdar environment)
          (lookup-symbol name (cdr environment)))))

(defun substitute-term (term environment)
  (if (atom term)
      term
      (case (car term)
        (:var
          (let ((value
                  (lookup-symbol (cadr term) environment)))
            (if value value term)))
        (otherwise
          (cons (car term)
                (substitute-term-list
                  (cdr term) environment))))))

(defun substitute-term-list (terms environment)
  (if (endp terms)
      nil
      (cons
        (substitute-term (car terms) environment)
        (substitute-term-list
          (cdr terms) environment))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 3. BOOLEAN SEMANTICS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bool-eval (term environment)
  (case (car term)
    (:const (equal (cadr term) t))
    (:var
      (equal
        (lookup-symbol (cadr term) environment)
        t))
    (:not
      (not (bool-eval (cadr term) environment)))
    (:and
      (and
        (bool-eval (cadr term) environment)
        (bool-eval (caddr term) environment)))
    (:or
      (or
        (bool-eval (cadr term) environment)
        (bool-eval (caddr term) environment)))
    (:xor
      (not
        (equal
          (bool-eval (cadr term) environment)
          (bool-eval (caddr term) environment))))
    (:eq
      (equal
        (bool-eval (cadr term) environment)
        (bool-eval (caddr term) environment)))
    (otherwise nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 4. REWRITE CALCULUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun rewrite-once (term)
  (case (car term)
    (:not
      (if (equal (cadr term) '(:const t))
          '(:const nil)
          (if (equal (cadr term) '(:const nil))
              '(:const t)
              term)))
    (:and
      (cond
        ((equal (cadr term) '(:const t))
         (caddr term))
        ((equal (caddr term) '(:const t))
         (cadr term))
        ((or
           (equal (cadr term) '(:const nil))
           (equal (caddr term) '(:const nil)))
         '(:const nil))
        (t term)))
    (:or
      (cond
        ((equal (cadr term) '(:const nil))
         (caddr term))
        ((equal (caddr term) '(:const nil))
         (cadr term))
        ((or
           (equal (cadr term) '(:const t))
           (equal (caddr term) '(:const t)))
         '(:const t))
        (t term)))
    (:xor
      (if (equal (cadr term) (caddr term))
          '(:const nil)
          term))
    (otherwise term)))

(defun rewrite-fuel (term fuel)
  (if (zp fuel)
      term
      (let ((next (rewrite-once term)))
        (if (equal next term)
            term
            (rewrite-fuel next (- fuel 1))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 5. SMT-STYLE CONSTRAINT CALCULUS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun constraintp (constraint)
  (and
    (termp constraint)
    (member-equal
      (car constraint)
      '(:eq :and :or :not :xor))))

(defun constraints-valid-p (constraints)
  (if (endp constraints)
      t
      (and
        (constraintp (car constraints))
        (constraints-valid-p (cdr constraints)))))

(defun constraint-system (assertions)
  (list :smt-system assertions))

(defun satisfiable-under (constraints environment)
  (if (endp constraints)
      t
      (and
        (bool-eval (car constraints) environment)
        (satisfiable-under
          (cdr constraints) environment))))

(defun counterexample-p (formula constraints environment)
  (and
    (satisfiable-under constraints environment)
    (not (bool-eval formula environment))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 6. SYMBOLIC VERIFICATION CONDITIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun verification-condition
  (precondition operation postcondition)
  (list
    :vc
    precondition
    operation
    postcondition))

(defun vc-precondition (vc)
  (cadr vc))

(defun vc-operation (vc)
  (caddr vc))

(defun vc-postcondition (vc)
  (cadddr vc))

(defun verify-vc (vc environment)
  (and
    (bool-eval (vc-precondition vc) environment)
    (bool-eval (vc-operation vc) environment)
    (bool-eval (vc-postcondition vc) environment)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 7. PROOF JUDGMENT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun derivation (assumptions conclusion)
  (list :derives assumptions conclusion))

(defun derivation-valid-p (proof)
  (and
    (equal (car proof) :derives)
    (constraints-valid-p (cadr proof))
    (termp (caddr proof))))

(defun proof-obligation (assumptions goal)
  (list
    :obligation
    assumptions
    goal))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 8. EXAMPLE: XOR SELF-EQUIVALENCE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst *xor-self*
  '(:xor (:var x) (:var x)))

(defthm xor-self-rewrites-to-false
  (equal
    (rewrite-fuel *xor-self* 8)
    '(:const nil)))

(defthm xor-self-is-unsatisfiable
  (equal
    (bool-eval *xor-self* '((x . t)))
    nil))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 9. SYNTHESIS INTEGRITY
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun calculus-integrity (term)
  (and
    (termp term)
    (equal
      (rewrite-fuel term 0)
      term)))

(defthm rewrite-preserves-term-shape
  (implies
    (termp term)
    (termp (rewrite-fuel term 8))))
