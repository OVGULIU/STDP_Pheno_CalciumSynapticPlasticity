function [rho_hist, w_hist, c_hist] = caProd_model( pre_spikes_hist, post_spikes_hist, params, simu)
%NAIVE_MODEL Simulates the behavior of a synapse whose behavior follows the
%naive Calcium_based dynamics
%   Detailed explanation goes here

%% Default parameter values + unpacking params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch nargin
    case 0
        pre_spikes_hist = [];
        post_spikes_hist = [];
        params = default_params();
        simu = default_simu();
    case 1
        post_spikes_hist = [];
        params = default_params();
        simu = default_simu();
    case 2
        params = default_params();
        simu = default_simu();
    case 3
        simu = default_simu();
    case 4
    otherwise
        error('4 inputs max are accepted')
end

%%%%%%%%%%%%%%%%%%%%
% Unpacking params %
%%%%%%%%%%%%%%%%%%%%

T = simu.T;
step = simu.int_step;
scheme = simu.int_scheme;
n_steps = T / step;

rho_0 = params.rho_0;
rho_max = params.rho_max;
C_pre = params.C_pre;
C_post = params.C_post;
tau_Ca = params.tau_Ca;
tau_x = params.tau_x;
delay_pre = params.delay_pre;
theta_dep = params.theta_dep;
gamma_dep = params.gamma_dep;
theta_pot = params.theta_pot;
gamma_pot = params.gamma_pot;
tau_rho = params.tau_rho;
sigma = params.noise_lvl;
S_attr = params.S_attr;
tau_w = params.tau_w;
theta_act = params.theta_act;
w_0 = params.w_0;

tau_CaPre = tau_Ca;
tau_CaPost = tau_Ca;
dampFactor = params.dampFactor;

prot = params;
prot.n_iter = 1;

prot.alpha_pot = 0;
prot.alpha_dep = 0;
prot.frequency = 1000/step;

%% Building events list based on calcium hypothesis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

len_pre = length(pre_spikes_hist);
len_post = length(post_spikes_hist);

evts = [];

%% Simulating process
%%%%%%%%%%%%%%%%%%%%%

if strcmp(scheme, 'euler_expl')
    % Initiate simulation %
    %%%%%%%%%%%%%%%%%%%%%%%
    rho = rho_0;
    w = w_0;
    t = 0;
    x_pre = 1;
    x_post = 1;
    c_pre = 0;
    c_post = 0;
    c = 0;
    
    rho_hist = rho;
    w_hist = w;
    c_hist = 0;

    % Check whether simulation is trivial %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if isempty(pre_spikes_hist) && isempty(post_spikes_hist)
        rho_hist = rho_0 * ones(n_steps);
        w_f = transfer(rho, prot);
        w_hist = (w_0-w_f)*exp(-step*(0:n_steps-1)/tau_w);
    else
        % Scheme propagation %
        %%%%%%%%%%%%%%%%%%%%%%
        while t < T
            c_hist = cat(1, c_hist, c);
            evt_pre = find(and(t - double(pre_spikes_hist) < step, t >= double(pre_spikes_hist)));
            evt_post = find(and(t - double(post_spikes_hist) < step, t >= double(post_spikes_hist)));
            if evt_pre
                % PRODUCT MODEL
                % c_pre = c_pre + C_pre;
                
                % SATURATION VARIABLE MODEL
                c_pre = c_pre + C_pre*x_pre;
                x_pre = x_pre*(1-dampFactor);
            end
            if evt_post
                % PRODUCT MODEL
                % c_post = c_post + C_post;
                
                % SATURATION VARIABLE MODEL
                c_post = c_post + C_post*x_post;
                x_post = x_post*(1-dampFactor);                
            end
            % PRODUCT MODEL
            % c = c_pre.*c_post;
            
            % ADDITIVE MODELS
            c = c_pre + c_post;
            
            rho = rho + step/tau_rho * (gamma_pot*(rho_max-rho)*(c > theta_pot) - gamma_dep*rho*(c > theta_dep)) * (c > theta_act);
            w_f = transfer(rho, prot);
            w = w + step/tau_w * (w_f-w);
            
            rho_hist = [rho_hist, rho];
            w_hist = [w_hist; w];
            x_pre = 1 - exp(-step/tau_x)*(1-x_pre);
            x_post = 1 - exp(-step/tau_x)*(1-x_post);
            c_pre = c_pre * exp(-step/tau_CaPre);
            c_post = c_post * exp(-step/tau_CaPost);
            t = t + step;
            
            prot.alpha_pot = (1+step/t)*(prot.alpha_pot+(step/t)*(c > theta_pot));
            prot.alpha_dep = (1+step/t)*(prot.alpha_dep+(step/t)*(c > theta_dep));
            prot.frequency = 1000/t;
        end
    end     
        
else
	error('This integration scheme is not currently handled')
end

end
