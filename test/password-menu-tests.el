;;; password-menu-tests.el --- Password Menu tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'password-menu)

(ert-deftest picker-string-test ()
  (should (string-equal (password-menu-picker-string 9) "9"))
  (should (string-equal (password-menu-picker-string 26) "b6"))
  )

(provide 'password-menu-tests)

;;; password-menu-tests.el ends here
