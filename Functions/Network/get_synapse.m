function syn = get_synapse( )
%GET_SYNAPSE Summary of this function goes here
%   Detailed explanation goes here
    syn.Cpre = 1;
    syn.Cpost = 2;
    
    syn.tDep = 1;
    syn.gDep = 200;
    
    syn.tPot = 1.3;
    syn.gPot = 320;
    
    syn.tauCa = 5e-2;
    syn.tauRho = 100;
    
    syn.rho0 = 40;
    syn.rhoMax = 200;
    syn.sAttr = 40;
    syn.sigma = 10;
    
end

