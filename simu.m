%% SIMULATION STARTER %%
% 1) Just defines the model, variables and integration scheme
% 2) Runs a single simulation and returns the full evolution of synaptic
% efficacy
% 3) Returns STDP curve by running simulation for several possible timings
% 4) Analyses the impact of frequency and of number of spike pairs on the
% plasticity during an experiment
% 5) Provides a frequency vs dt heatmap
% 6) Provides a STDP = f(n_pairs) for dt=+10ms and dt=-10ms

% Simulation mode
% single    Step 2 only
% STDP      Step 3 only
% freq      Step 4 only
% all       All steps

mode = 'STDP';

%% 0) Define the environment

T = 200;
rho_0 = 35; % must be between 0 and
rho_max = 200;
S_attr = 40;
w_0 = transfer(rho_0, S_attr, 10);

C_pre = 0.7;
C_post = 1;
tau_Ca = 20;
delay_pre = -5;
Ca_params = [C_pre, C_post, tau_Ca, delay_pre];

theta_dep = 0.8;
gamma_dep = 50;
dep_params = [theta_dep, gamma_dep];

theta_pot = 1.1;
gamma_pot = 30;
pot_params = [theta_pot, gamma_pot];

tau_rho = 1000; % this is larger than I expected. Ask Brunel about this
tau_w =10000;

N_A = 6.02e23; %mol^(-1)
V = 2.5e-16; %L
theta_act = 0.6;

% Modeling noise
noise_lvl = 10; %1/sqrt(N_A*V);

n_iter = 10;
frequency = 1;

model_params = [T, rho_0, Ca_params, dep_params, pot_params, tau_rho, noise_lvl];
model = 'pheno'; %naive or pheno

int_scheme = 'euler_expl';
scheme_step = 0.5;

%% 1) Define the stimulation history
d_t = 15;
pre_spikes_hist = linspace(0, 1000*(n_iter-1)/frequency, n_iter);
post_spikes_hist = pre_spikes_hist + d_t;
T = 1000*(n_iter-1)/frequency + 10*tau_Ca;
model_params(1) = T;

%% 2) Full evolution of syn plast on a single simulation
if strcmp(mode, 'single') || strcmp(mode, 'all')
    if strcmp(model, 'naive')
        [rho_hist, c_hist] = naive_model(pre_spikes_hist, post_spikes_hist, model_params, int_scheme, scheme_step);
    elseif strcmp(model, 'pheno')
        model_params = [T, rho_0, w_0, Ca_params, dep_params, pot_params, tau_rho, tau_w, theta_act, noise_lvl];
        [rho_hist, w_hist, c_hist] = pheno_model(pre_spikes_hist, post_spikes_hist, model_params, int_scheme, scheme_step);
    end

    % Plotting rho as a function of time
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    t = linspace(0, T, T/scheme_step + 1);

    figure(1)
    plot(t, rho_hist);
    title('Evolution of average CaMKII state');
    xlabel('Time');
    ylabel('Average CaMKII state');

    % ToDo: add bumps of Ca as colored pins over x-axis

    figure(2)
    plot(t, c_hist);
    title('Evolution of calcium influx');
    xlabel('Time');
    ylabel('Calcium concentration');

    dep_thr = refline([0 theta_dep]);
    dep_thr.Color = 'r';

    pot_thr = refline([0 theta_pot]);
    pot_thr.Color = 'g';
    
    act_thr = refline([0 theta_act]);
    act_thr.Color = 'm';
    
    if strcmp(model, 'pheno')
        figure(3)
        plot(t, w_hist);
        title('Evolution of synaptic strength')
        xlabel('Time');
        ylabel('Average synaptic strength');
    end
end

%% 3) STDP curve

% Obtaining STDP curve
%%%%%%%%%%%%%%%%%%%%%%
if strcmp(mode, 'STDP') || strcmp(mode, 'all')
    t_min = -75;
    t_max = 75;
    dt = 3;

    stdp_params = [model_params, t_min, t_max, dt, n_iter, frequency];
    if strcmp(model, 'naive')
        STDP = get_STDP(model, 'rel', stdp_params, int_scheme, scheme_step);
    elseif strcmp(model, 'pheno')
        drho = get_STDP(model, 'abs', stdp_params, int_scheme, scheme_step);
        STDP = [drho(:,1),transfer(rho_0+drho(:,2), S_attr, noise_lvl)./w_0];
    end
    % Validation against simulation
    % [STDP_an, STDP_sim] = get_both_STDP(model, 'rel', stdp_params, int_scheme, scheme_step);

    figure(3)
    plot(STDP(:,1), STDP(:,2), '+r');
%     plot(STDP_an(:,1), STDP_an(:,2), '+r');
%     hold on
%     plot(STDP_sim(:,1), STDP_sim(:,2), 'xg');
    
    title('Plasticity as a function of pre-post spike delay')
    xlabel('Pre-post spike delay (ms)')
    ylabel('Relative change in synaptic strength')

    neutral_hline = refline([0 1]);
    neutral_hline.Color = 'b';
    
%     YL = get(gca,'ylim');
%     YL(1) = 2 - YL(2);
%     set(gca, 'ylim', YL)
    
end

%% 4) Analysis of frequency and number of spike pairs
if strcmp(mode, 'freq') || strcmp(mode, 'all')
    dt = 10;

    freq_def = 100;
    n_iter_max = 200;

    n_iter_def = 100;
    freq_min = 1;
    freq_max = 50;

    freq_an_params = [model_params, dt, freq_def, n_iter_max, n_iter_def, freq_min, freq_max];

    [
        dw_freq_prepost, ...
        dw_freq_postpre, ...
        dw_npairs_prepost, ...
        dw_npairs_postpre ...    
    ] ...
    = get_freq_an(model, freq_an_params, int_scheme, scheme_step);


    figure(4)

    plot(dw_freq_prepost(:,1), dw_freq_prepost(:,2), '+')
    hold on
    plot(dw_freq_postpre(:,1), dw_freq_postpre(:,2), '+')

    xlabel('Frequency (Hz)')
    ylabel('Relative change in synaptic weight')
    legend('dt = +10ms','dt = -10ms')
    title('Plasticity as a function of frequency (Hz), for 60 pairings at +-10ms')

    hold off


    figure(5)

    plot(dw_npairs_prepost(:,1), dw_npairs_prepost(:,2), '+')
    hold on
    plot(dw_npairs_postpre(:,1), dw_npairs_postpre(:,2), '+')

    xlabel('Nb of spike pairs at 1Hz');
    ylabel('Relative change in synaptic weight');
    legend('dt = +10ms','dt = -10ms')
    title('Plasticity as a function of the number of spike pairs, for pairings at +-10ms, at 1Hz')

    hold off
end

%% 5) Frequency - dt - heatmap
if strcmp(mode, 'freq_heat')
    tmin = -75;
    tmax = 75;
    dt = 3;
    freq_min = 1;
    freq_max = 2;
    freq_step = 2;
    n_iter = 10;
    heatmap_params = [tmin, tmax, dt, freq_min, freq_max, freq_step, n_iter];
    
    heatmap = get_freq_heatmap(model, model_params, heatmap_params, int_scheme, int_step);
    
    figure(6)
    heatfreq_plot = heatmap(heatmap(:,3),heatmap(:,1),heatmap(:,2));
    heatfreq_plot.Title = 'Relative change in syn plast as a function of frequency and dt';
    heatfreq_plot.XLabel = 'Frequency';
    heatfreq_plot.YLabel = 'dt';
end

%% 6)Nb Paris - dt - heatmap
if strcmp(mode, 'pairs_stdp')
    
end