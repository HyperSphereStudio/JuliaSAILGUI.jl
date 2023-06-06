export polyval

polyval(coeffs, x) = sum(i -> coeffs[i] * x ^ (i - 1), length(coeffs):-1:1)