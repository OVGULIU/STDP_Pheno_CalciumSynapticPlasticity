function [times, rho_hist, w_end, c_hist] = pheno_model( pre_spikes_hist, post_spikes_hist, params, int_scheme, int_step)
%NAIVE_MODEL Simulates the behavior of a synapse whose behavior follows the
%naive Calcium_based dynamics
%   Detailed explanation goes here

%% Default parameter values + unpacking params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

def_params = [...
    1000 ...        % T             total simu time     (ms)
    .3 ...          % rho_0         init syn strength
    1 ...           % C_pre
    2 ...           % C_post
    20 ...          % tau_Ca
    3 ...           % delay_pre
    1 ...           % theta_dep
    200 ...         % gamma_dep
    1.3 ...         % theta_pot
    321 ...         % gamma_pot
    150 ...         % tau_rho           syn plast time cst  (ms)
    0.6 ...         % theta_act
    0 ...           % sigma
    .3 ...          % w_0
    1000 ...        % tau_w
    ];

switch nargin
    case 0
        pre_spikes_hist = [];
        post_spikes_hist = [];
        params = def_params;
        int_scheme = 'euler_expl';
        int_step = 0.1;
    case 1
        post_spikes_hist = [];
        params = def_params;
        int_scheme = 'euler_expl';
        int_step = 0.1;
    case 2
        params = def_params;
        int_scheme = 'euler_expl';
        int_step = 0.1;
    case 3
        int_scheme = 'euler_expl';
        int_step = 0.1;
    case 4
        int_step = 0.1;
    case 5
    otherwise
        error('5 inputs max are accepted')
end

%%%%%%%%%%%%%%%%%%%%
% Unpacking params %
%%%%%%%%%%%%%%%%%%%%

T = params(1);
rho_0 = params(2);
rho_max = params(3);

step = int_step;
n_steps = T / step;

C_pre = params(4);
C_post = params(5);
tau_Ca = params(6);
delay_pre = params(7);

theta_dep = params(8);
gamma_dep = params(9);

theta_pot = params(10);
gamma_pot = params(11);

tau_rho = params(12);
sigma = params(13);

w_0 = params(14);
tau_w = params(15);
theta_act = params(16);

eq_thr = 1e-5;
S_attr = 40;
rho_max = 200;

%% Building events list based on calcium hypothesis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

len_pre = length(pre_spikes_hist);
len_post = length(post_spikes_hist);

evts = [];

if len_pre > 0
    for pre_evtID=1:len_pre
        evts = cat(1, evts, [pre_spikes_hist(pre_evtID) + delay_pre, C_pre]);
    end
end

if len_post > 0
    for post_evtID=1:len_post
        evts = cat(1, evts, [post_spikes_hist(post_evtID),C_post]);
    end
end

evts = sortrows(evts, 1);
evts_dur = evts - circshift(evts,1);
evts_dur(1) = evts(1);


%% Simulating process
%%%%%%%%%%%%%%%%%%%%%

% Initiate simulation %
%%%%%%%%%%%%%%%%%%%%%%%
rho = rho_0;
w = w_0;
t = 0;
c = 0;

rho_hist = rho;
c_hist = 0;


% Check whether simulation is trivial %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isempty(evts)
    rho_hist = rho_0 * ones(n_steps);
else

    
    % Figure out the calcium history %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    c_hist = [];
    for bump_id = 1:length(evts)
        tn = evts(bump_id, 1);
        c = evts(bump_id, 2) + c*exp(-(tn-t)/tau_Ca);
        c_hist = [c_hist; c];
        t = tn;
    end


    % Extract period objects for which the calcium is above thresholds %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    t_openPot = evts(c_hist>theta_pot,1);
    c_openPot = c_hist(c_hist>theta_pot);
    t_maxDurPot = tau.*log(c_openPot/theta_pot);
    t_durPot = min(circshift(t_openPot, 1) - t_openPot, tau_Ca.*log(c_openPot./theta_pot));
    t_durPot(1) = t_openPot(1);

    t_openDep = evts(c_hist>theta_dep,1);
    c_openDep = c_hist(c_hist>theta_dep);
    t_maxDurDep = tau.*log(c_openDep/theta_dep);
    t_durDep = min(circshift(t_openDep, 1) - t_openDep, tau_Ca.*log(c_openDep./theta_dep));
    t_durDep(1) = t_openDep(1);

    t_durPot = cat(1, t_durPot, ones(length(t_durPot),1));
    t_durDep = cat(1, t_durDep, -1.*ones(length(t_durDep),1));

    t_dur = cat(2, t_durPot, t_durDep);
    t_dur = sortrows(t_dur, [1 2]);

    t_durOverlap = (t_dur(:,1) - circshift(t_dur(:,1)) == 0);
    substitute = circshift(t_dur(:,2));
    t_dur(t_durOverlap,1) = substitute(t_durOverlap);


    % Finding rho %
    %%%%%%%%%%%%%%%%%%%%%%

    for id=1:length(t_dur)
        rho_f = (rho - gam_pot/(gam_pot+gam_dep))*exp(-t_dur(id,2)*(gam_pot+gam_dep)/tau_rho) + gam_pot/(gam_pot+gam_dep) .* (t_dur(id,3)==1) ...
            +(a).*(t_dur(id,3)==-1);
        rho = rho_f;
        rho_hist = cat(1, rho_hist, rho);
    end

    times = cat(1, t_dur(:,1), t_dur(end,2));
    w_end = transfer(rho_hist(end),S_attr,sigma);
end

end    
