clear all

% syms C Su Sp K5 K9;
syms gam_u gam_p;

assume(gam_u, 'real')
assume(gam_p, 'real')

Su = 199.8;
Sp = 0;
k10 = 0;
PP1 = 0;

K5 = 0.1;
K9 = 1e-4;
L1=0.1;
L2=0.025;
L3=0.32;
L4=0.40;
CaM=10;
CaBas=0.4;
k18=0.0005;
k17=10;

C = CaM/(1 + L4/CaBas + L3*L4/(CaBas^2) + L2*L3*L4/(CaBas^3) + L1*L2*L3*L4/(CaBas^4));

a = solve([
    (1-gam_u)*(C - gam_u*Su - gam_p*Sp) - K5*gam_u == 0,
    (1-gam_p)*(C - gam_u*Su - gam_p*Sp) - K9*gam_p == 0,
    gam_u>=0,
    gam_u<=1,
    gam_p>=0,
    gam_p<=1
    ],[gam_u,gam_p]...
);


double(a.gam_u)
double(a.gam_p)


b = vpasolve([
    (1-gam_u)*(C - gam_u*Su - gam_p*Sp) - K5*gam_u == 0,
    (1-gam_p)*(C - gam_u*Su - gam_p*Sp) - K9*gam_p == 0,
    ],[gam_u,gam_p],[0 1;0 1]...
);

double(b.gam_u)
double(b.gam_p)

% a = vpasolve([
%     (1-gam_u-zet_u)*(C - gam_u*Su - gam_p*Sp) - K5*gam_u == 0,
%     (1-gam_p-zet_p)*(C - gam_u*Su - gam_p*Sp) - K9*gam_p == 0,
%     k18*(1-gam_u-zet_u) - k10*zet_u*PP1 == 0,
%     k17*(1-gam_p-zet_p) - k10*zet_p*PP1 == 0,
%     r_u==gam_u+zet_u;
%     r_p==gam_p+zet_p;
%     ],[gam_u,gam_p,zet_u,zet_p,r_u,r_p],[0 1 ; 0 1 ; 0 1; 0 1; 0 1; 0 1;]...
% );

% C = 0:0.005:1;
% can = 0.1 + 18./(1 + (0.053./C).^3);
% pka = 0.00359 + 100./(1 + (0.11./C).^8);
% 
% figure()
% plot(C,pka./can)