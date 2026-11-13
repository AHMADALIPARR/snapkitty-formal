(defun factorial (n)
  (if (zp n) 1 (* n (factorial (- n 1)))))
(defthm factorial-positive
  (implies (natp n) (< 0 (factorial n))))
