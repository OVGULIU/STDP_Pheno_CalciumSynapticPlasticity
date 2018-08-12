function rho = transferinv(w, S_attr, sigma, rho_max)
%ZETA Summary of this function goes here
%   Detailed explanation goes here

if nargin == 1
    S_attr = 40;
    sigma = 20; % replace with default sigma from G&B 2007
    rho_max = 200;
end

rho = min(max(0, S_attr - 2*sigma.^2.*erfcinv(w)), rho_max);

end

