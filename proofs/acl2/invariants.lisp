(in-package "ACL2")
(defun snapkitty-add-zero (x) (+ x 0))
(defthm snapkitty-add-zero-identity (equal (snapkitty-add-zero x) (ifix x)))
