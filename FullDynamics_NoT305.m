clear all;

% Naming conventions
% k --- reaction constant
% r --- reaction rate ------------------------------- r_{11} = k_{11}*[C_p]*[PP1_{free}]
% K --- dissociation constant ----------------------- K_5 = k_{-5} / k_{5}
% KM -- Michaelis constant for catalytic reaction --- KM_Dpu = (k_{-11} + k_{12})/k_{11}

% All time units in s
% All concentrations in microMolars = 1mumol/L

% Vector variable
% ID 	Name 		Description
% 1		Ca 			Free calcium
% 2		C 			Free Ca2+/CaM
% 3		gam_u 		Rate of CaM-bound monomers among T-286 unphosphorilated CaMKII
% 4		gam_p		Rate of CaM-bound monomers among T-286 phosphorilated CaMKII
% 5		zet_u		Rate of T-306 phosphorylated monomers among T-286 unphosphorilated CaMKII
% 6 	zet_p		Rate of T-306 phosphorylated monomers among T-286 phosphorilated CaMKII
% 7		k10 		Dephosphorylation rate
% 8		B0 			Concentration of olygomer 0 (fully dephosphorylated)
% 9		B1 			Concentration of olygomer 1
% 10	B2 			Concentration of olygomer 2
% 11	B3 			Concentration of olygomer 3
% 12	B4 			Concentration of olygomer 4
% 13	B5 			Concentration of olygomer 5
% 14	B6 			Concentration of olygomer 6
% 15	B7 			Concentration of olygomer 7
% 16	B8 			Concentration of olygomer 8
% 17	B9 			Concentration of olygomer 9
% 18	B10 		Concentration of olygomer 10
% 19	B11			Concentration of olygomer 11
% 20	B12			Concentration of olygomer 12 
% 21	B13			Concentration of olygomer 13
% 22	chi 		Intermediate expression for comp of B1'..B13'
% 23	nu 			Intermediate expression for comp of B1'..B13'
% 24	rr 			Sum(B1..B13)
% 25	Sp 			Total concentration of T-286 phosphorylated CaMKII monomers
% 26	Su 			Total concentration of T-286 unphosphorylated CaMKII monomers
% 27	AMPA_bnd	Concentration of CamKII monomer available for AMPA phosphorylation
% 28	vPKA_I1		Phosphorylation rate of I1 by PKA
% 29	vPKA_phos	Phosphorylation rate of AMPA by PKA
% 30	vCaN_I1		Phosphatase rate of I1 by CaN
% 31	vCaN_endo	Endocytosis rate of AMPA receptors by CaN
% 32	vPP1_pase	Phosphatase rate of AMPA receptors by PP1
% 33	vCK2_exo	Exocytosis rate of AMPA receptors by CaMKII-NMDA
% 34 	PP1 		Concentration of active PP1
% 35 	I1 			Concentration of phosphorylated PP inhibitor 1
% 36	mu 			Concentration of CaMKII-NMDA complexes
% 37 	U 			Phosphorylation potential from CaMKII-NMDA complexes
% 26	n0 			Number of AMPA in phosphorylation state 0 (fully dephosphorylated)
% 27	n1 			Number of AMPA in phosphorylation state 1

% VARIABLES AND PARAMETERS

%Variables
syms C(t)
syms gam_u(t) gam_p(t) k10(t)
syms B0(t) B1(t) B2(t) B3(t) B4(t) B5(t) B6(t) B7(t) B8(t) B9(t) B10(t) B11(t) B12(t) B13(t) chi(t) nu(t) rr(t)
syms Sp(t) Su(t) AMPA_bnd(t) Cb(t) 
syms vPKA_I1(t) vPKA_phos(t) vCaN_I1(t) vCaN_endo(t) vPP1_pase(t) vCK2_exo(t)
syms PP1(t) I1P(t) mu(t) U(t)
%Params
syms tauCa CaBas Stot CaM K5 K9 L1 L2 L3 L4 k6 k7 k8 KM k12 k11 km11 I10 PP10 Kdcan ncan
syms kcan0_I1 kcan_I1 kcan0_endo kcan_endo kPP10_pase kPP1_pase Kdpka npka kpka0_I1 kpka_I1 kpka0_phos kpka_phos
syms kCK2_exo kNMDA_bind N g0 g1 g2 M

% QUANTITIES AND EQUATIONS

% Membrane AMPA dynamics
% ode_n0 = diff(n0) == vCK2_exo*(N-n0-n1) - vCaN_endo*n0 - vPKA_phos*n0*U + vPP1_pase*n1*PP1;
% ode_n1 = iff(n1) == vPKA_phos*n0*U - vPP1_pase*n1*PP1;

% W = g0*n0 + g1*n1;

daes = [
	(1-gam_u(t))*(C(t) - gam_u(t)*Su(t) - gam_p(t)*Sp(t)) - K5*gam_u(t) == 0;
	(1-gam_p(t))*(C(t) - gam_u(t)*Su(t) - gam_p(t)*Sp(t)) - K9*gam_p(t) == 0;
    
    rr(t) == B1(t) + B2(t) + B3(t) + B4(t) + B5(t) + B6(t) + B7(t) + B8(t) + B9(t) + B10(t) + B11(t) + B12(t) + B13(t);
    B0(t) == Stot - rr(t);

    Sp(t) == B1(t) + 2*(B2(t) + B3(t) + B4(t)) + 3*(B5(t) + B6(t) + B7(t) + B8(t)) + 4*(B9(t) + B10(t) + B11(t)) + 5*B12(t) + 6*B13(t);
    Su(t) == 6*Stot - Sp(t);

    k10(t) == k12*PP1(t)/(KM + Sp(t));
    C(t) == CaM/(1 + L4/CaBas + L3*L4/(CaBas^2) + L2*L3*L4/(CaBas^3) + L1*L2*L3*L4/(CaBas^4));
    Cb(t) == gam_u(t)*Su(t) + gam_p(t)*Sp(t);

    chi(t) == k7*gam_p(t) + k8*(1 - gam_p(t));
    nu(t) == k10(t);
    
    AMPA_bnd(t) == 2*(B2(t)+B3(t)+B4(t)) + 6*(B5(t)+B6(t)+B7(t)+B8(t)) + 12*(B9(t)+B10(t)+B11(t)) + 20*B12(t) + 30*B13(t);

    vPKA_I1(t) == kpka0_I1 + kpka_I1/(1 + (Kdpka/C(t))^npka);
    vPKA_phos(t) == kpka0_phos + kpka_phos/(1 + (Kdpka/C(t))^npka);

    vCaN_I1(t) == kcan0_I1 + kcan_I1/(1 + (Kdcan/C(t))^ncan);
    vCaN_endo(t) == kcan0_endo + kcan_endo/(1 + (Kdcan/C(t))^ncan);

    vPP1_pase(t) == kPP10_pase + kPP1_pase/(1 + (Kdcan/C(t))^ncan);

    vCK2_exo(t) == kCK2_exo*Sp(t);
];

odes = [
	diff(B1(t), t) == 6*k6*gam_u(t)^2*B0(t) - 4*k6*gam_u(t)^2*B1(t) - chi(t)*gam_u(t)*B1(t) + nu(t)*(2*(B2(t)+B3(t)+B4(t))-B1(t)) - kNMDA_bind*(M-mu(t))*B1(t);
	diff(B2(t), t) == k6*gam_u(t)^2*B1(t) + chi(t)*gam_u(t)*B1(t) + nu(t)*(3*(B5(t)+B6(t)+B7(t)+B8(t))-2*B2(t)) - 3*k6*gam_u(t)^2*B2(t) - chi(t)*gam_u(t)*B2(t) - 2*kNMDA_bind*(M-mu(t))*B2(t);
	diff(B3(t), t) == 2*k6*gam_u(t)^2*B1(t) + nu(t)*(3*(B5(t)+B6(t)+B7(t)+B8(t))-2*B3(t)) - 3*k6*gam_u(t)^2*B3(t) - chi(t)*gam_u(t)*B3(t) - 2*kNMDA_bind*(M-mu(t))*B3(t);
	diff(B4(t), t) == k6*gam_u(t)^2*B1(t) + nu(t)*(3*(B5(t)+B6(t)+B7(t)+B8(t))-2*B4(t)) - 2*k6*gam_u(t)^2*B4(t) - 2*chi(t)*gam_u(t)*B4(t) - 2*kNMDA_bind*(M-mu(t))*B4(t);
	diff(B5(t), t) == k6*gam_u(t)^2*(B2(t)+B3(t)) + chi(t)*gam_u(t)*B2(t) + nu(t)*(4*(B9(t)+B10(t)+B11(t))-3*B5(t)) - 2*k6*gam_u(t)^2*B5(t) - chi(t)*gam_u(t)*B5(t) - 3*kNMDA_bind*(M-mu(t))*B5(t);
	diff(B6(t), t) == k6*gam_u(t)^2*(B2(t)+B3(t)) + 2*chi(t)*gam_u(t)*B4(t) + nu(t)*(4*(B9(t)+B10(t)+B11(t))-3*B6(t)) - k6*gam_u(t)^2*B6(t) - 2*chi(t)*gam_u(t)*B6(t) - 3*kNMDA_bind*(M-mu(t))*B6(t);
	diff(B7(t), t) == k6*gam_u(t)^2*(B2(t)+2*B4(t)) + chi(t)*gam_u(t)*B3(t) + nu(t)*(4*(B9(t)+B10(t)+B11(t))-3*B7(t)) - k6*gam_u(t)^2*B7(t) - 2*chi(t)*gam_u(t)*B7(t) - 3*kNMDA_bind*(M-mu(t))*B7(t);
	diff(B8(t), t) == k6*gam_u(t)^2*B3(t) + nu(t)*(4*(B9(t)+B10(t)+B11(t))-3*B8(t)) - 3*chi(t)*gam_u(t)*B8(t) - 3*kNMDA_bind*(M-mu(t))*B8(t);
	diff(B9(t), t) == k6*gam_u(t)^2*B5(t) + chi(t)*gam_u(t)*(B6(t)+B7(t)) + nu(t)*(5*B12(t)-4*B9(t)) - k6*gam_u(t)^2*B9(t) - chi(t)*gam_u(t)*B9(t) - 4*kNMDA_bind*(M-mu(t))*B9(t);
	diff(B10(t), t) == k6*gam_u(t)^2*(B5(t)+B6(t)) + chi(t)*gam_u(t)*(B7(t)+B8(t)) + nu(t)*(5*B12(t)-4*B10(t)) - 2*chi(t)*gam_u(t)*B10(t) - 4*kNMDA_bind*(M-mu(t))*B10(t);
	diff(B11(t), t) == k6*gam_u(t)^2*B7(t) + chi(t)*gam_u(t)*B6(t) + nu(t)*(5*B12(t)-4*B11(t)) - 2*chi(t)*gam_u(t)*B11(t) - 4*kNMDA_bind*(M-mu(t))*B11(t);
	diff(B12(t), t) == k6*gam_u(t)^2*B9(t) + chi(t)*gam_u(t)*(B9(t)+2*B10(t)+2*B11(t)) + nu(t)*(6*B13(t)-5*B12(t)) - chi(t)*gam_u(t)*B12(t) - 5*kNMDA_bind*(M-mu(t))*B11(t);
	diff(B13(t), t) == chi(t)*gam_u(t)*B12(t) - nu(t)*6*B13(t) - 6*kNMDA_bind*(M-mu(t))*B13(t);
	diff(PP1(t), t) == -k11*I1P(t)*PP1(t) + km11*(PP10 - PP1(t));
	diff(I1P(t), t) == -k11*I1P(t)*PP1(t) + km11*(PP10 - PP1(t)) + vPKA_I1(t)*(I10-I1P(t)) - vCaN_I1(t)*I1P(t);
	diff(mu(t), t) == kNMDA_bind*(M-mu(t))*Sp(t);
	diff(U(t), t) == kNMDA_bind*(M-mu(t))*AMPA_bnd(t);
       % TOTAL 18 ODEs
];

eqs = [odes;daes];

vars = [
	C(t);
	gam_u(t); gam_p(t); k10(t);
	B0(t); B1(t); B2(t); B3(t); B4(t); B5(t); B6(t); B7(t); B8(t);
    B9(t); B10(t); B11(t); B12(t); B13(t); chi(t); nu(t); rr(t);
	Sp(t); Su(t); AMPA_bnd(t); Cb(t);
	vPKA_I1(t); vPKA_phos(t); vCaN_I1(t); vCaN_endo(t); vPP1_pase(t); vCK2_exo(t);
	PP1(t); I1P(t);
    mu(t); U(t)                                                     
];

y0est = [
	0.41;
	0.00206; 0.674; 0;
	33.3; 0; 0; 0; 0; 0; 0; 0; 0;
    0; 0; 0; 0; 0; 0; 0; 0;
	0; 0; 0; 0;
	0; 0; 0; 0; 0; 0;
	0; 0;
    0; 0
];

y0fix = [
	0;
	0; 0; 0;
	0; 1; 1; 1; 1; 1; 1; 1; 1;
    1; 1; 1; 1; 1; 0; 0; 0;
	0; 0; 0; 0;
	0; 0; 0; 0; 0; 0;
	0; 0;
    0; 0
];

params = [
	tauCa; CaBas;
	Stot; CaM;
	K5; K9;
	L1; L2; L3; L4;
	k6; k7; k8;
	KM; k12;
	k11; km11; I10; PP10;
	Kdcan; ncan; kcan0_I1; kcan_I1; kcan0_endo; kcan_endo;
	kPP10_pase; kPP1_pase;
	Kdpka; npka; kpka0_I1; kpka_I1; kpka0_phos; kpka_phos;
	kCK2_exo; kNMDA_bind;
	N; g0; g1; g2; M
];

paramVals = [
	0.012; 0.1;
	33.3; 10;
	0.1; 0.0001;
	0.1; 0.025; 0.32; 0.40;
	6; 6; 6;
	0.4; 6000;
	500; 0.1; 1; 0.2;
	0.053; 3; 0.1; 18; 0.1; 18;
	0.1; 18;
	0.11; 8; 0.00359; 100; 0.00359; 100;
	0.0005; 0; %kNMDA_bind temporarilly set to 0
	1000; 0.0010; 0.0017; 0.0024; 100
];

[mass,F] = massMatrixForm(eqs, vars);
mass = odeFunction(mass, vars);
F = odeFunction(F, vars, params);
f = @(t, y) F(t, y, paramVals);

t0=0; tfinal=5;

opt = odeset('Mass', mass,...
'AbsTol',1e-6,...
'RelTol',1e-3);

implicitDAE = @(t,y,yp) mass(t,y)*yp - f(t,y);
[y0, yp0] = decic(implicitDAE, t0, y0est, y0fix, zeros(35,1), [], opt);
%opt = odeset(opt, 'InitialSlope', yp0);

[t,y] = ode15s(f, [t0, tfinal], y0, opt);

plt_h=4; plt_l=4;
for idx = 1:length(vars)
    if mod(idx,plt_h*plt_l)==1
        figure(4 + fix(idx/(plt_h*plt_l)))
        set(gcf, 'Position', get(0, 'Screensize'));
    end
    subplot(plt_h,plt_l,1+mod(idx-1,plt_h*plt_l))
    plot(t(:,1),y(:,idx), 'x')
    title(char(vars(idx)))
end