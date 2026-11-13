(in-package "ACL2")

(defun sk-xor (a b)
  (logxor a b))

(defthm xor-zero-right
  (equal (sk-xor x 0)
         (ifix x)))

(defthm xor-commutative
  (equal (sk-xor x y)
         (sk-xor y x)))
