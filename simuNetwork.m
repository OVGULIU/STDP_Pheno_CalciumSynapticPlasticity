% Simulation of the Brunel JCNS 2000 network with electrode recording
% spikes (for paper Destexhe Touboul on Criticality).

% Modified by S. Lebastard, 2018
% Should accomodate mutliple models of plasticity, including none
% Should allow for heterogeneous synapse rules, ie manipulation of matrix
% of parameters

% ToDo
% - Refactorize code to gain modularity, be more readable
% - Allow user to start either with uniform weights or with random weights
% - Create clusterization index and look at its evolution
%   For this purpose, use techniques from spectral clustering

clear all
close all

% Add plot tools to path
env = getEnv();
addpath(genpath(env.functionsRoot));


%% Parameterization

% %%%%%%%%   PARAMETERS OF THE SIMULATION  %%%%%%%% 

syn = getSynapse();
prot.TD = 0;
prot.S_attr = syn.sAttr;
prot.noise_lvl = syn.sigma;

simu.T = 5;
simu.dt=5e-4;
net.N=400;
Iterations=ceil(simu.T/simu.dt);

plt.all.raster = 2;
plt.spl.ca = 0;
plt.spl.rho = 0;
plt.spl.w = 0;
plt.spl.pres = 3;
plt.spl.hist = 1;
plt.spl.phase = 0;

plt.timeSpl.n = 3;
plt.timeSpl.dur = 0.02*simu.T;
plt.timeSpl.inter = 50;

gif.graph = 0;
gif.lapl = 0;

init.w = 'norm';
init.c = 0.7;
init.mode = 'rand';
init.strap = 0;     % Time (s) for which the system should run before monitoring starts

% %%%%%%%%   PARAMETERS OF THE NETWORK  %%%%%%%%   

net.NE=ceil(0.8*net.N);      % # excitatory neurons
net.NI=net.N-net.NE;             % # excitatory neurons

net.Connectivity=0.1;           % Connectivity coefficients, parameter epsilon in Brunel 2000.
net.D=3e-3;                        % Transmission Delay
CE=round(net.Connectivity*net.NE);          % Number of exc connections
CI=round(net.Connectivity*net.NI);          % Number of inh connections
C_ext=CE;


% %%%%%%%%   PARAMETERS OF THE NEURONS  %%%%%%%%   

% Threshold, reset, time constant and refractory period (p.185, 2nd column,
% Brunel 2000)
V_t=20e-3;
V_r=10e-3;
tau=20e-3;
t_rp=2e-3;

% Bifurcation parameters
J=0.2e-3; %0.1e-3;                   % Strength of exc. Connections
net.g=4.5;                      % Strength of inh/exc (inh connections -gJ)
net.ratioextthresh=3;         % nu_ext/nu_thresh

nu_thresh=V_t/(J*CE*tau);   % Frequency needed for a neuron to reach the threshold. 
nu_ext=net.ratioextthresh*nu_thresh;       % external Poisson input rate


% %%%%%%%%   PARAMETERS OF THE ELECTRODES  %%%%%%%%  
L=100;          % Size of the cortex
NCX=8;          % Number of electrodes rows
NCY=8;          % Number of electrodes columns
NC=NCX*NCY;     % Total number of electrodes

% Parameters of histograms
nbins = 100;
edgesRho = linspace(0,syn.rhoMax,nbins+1);
edgesW_exc = linspace(0,1,nbins+1);
edgesW_inh = linspace(-net.g,0,nbins+1);

%% Creating network

% %%%%%% INITIALIZING SYNAPTIC QTIES %%%%%%

% %%% Synaptic weights %%%
W = zeros(net.N,net.N);   % 1st index for postsynaptic neuron, 2nd for presynaptic

for i=1:net.N
    ECells=randperm(net.NE);
    ECells=ECells(1:CE);
    W(i,ECells) = strcmp(init.mode, 'rand').*2.*init.c.*J.*rand(1,CE) + ~strcmp(init.mode, 'rand').*init.c.*J;
    
    ICells=randperm(net.NI);
    ICells=net.NE+ICells(1:CI);
    W(i,ICells)=-strcmp(init.mode, 'rand').*2.*net.g.*init.c.*J.*rand(1,CI) -~strcmp(init.mode, 'rand').*init.c .*net.g*J;
end

synSign = J.*(W>0) - net.g*J.*(W<0);


% Mean stats for phase plot
meanWexc = mean(W((1/J).*W>0)).*ones(Iterations+1,1);
meanWinh = mean(W((1/J).*W<0)).*ones(Iterations+1,1);

rateEst = zeros(net.N, Iterations);
histRates = zeros(nbins, Iterations);

G = digraph(W');    % Graph for plotting evolution of network
A = abs(W + W'); % Weight matrix for spectral clustering
% Symmetrization, all information on directionnality is lost
histRho = zeros(nbins, Iterations);
histW_exc = zeros(nbins, Iterations);
histW_inh = zeros(nbins, Iterations);

% %%% Other qties %%%
ca = zeros(net.N,net.N);
xpre = ones(net.N,net.N);
xpost = ones(net.N,net.N);
% rho = zeros(net.N,net.N);
rho = transferinv(W./synSign, syn.sAttr, syn.sigma, syn.rhoMax);
actPot = zeros(net.N,net.N);
actDep = zeros(net.N,net.N);


% %%% Electrodes wiring %%%
% Electrodes are regularly located, we compute the attenuation coefficient
% due to the distance. 

[X,Y] = meshgrid((1:8)',(1:8)');
POSC =10* [X(:) Y(:)];              % Positions of electrodes
POSN=L*rand(net.N,2);                   % Positions of the neurons

DCN=zeros(NCX*NCY,net.N);
for i=1:(NCX*NCY)
    for j=1:net.N
        DCN(i,j)=sqrt((POSC(i,1)-POSN(j,1))^2+(POSC(i,2)-POSN(j,2))^2);
    end
end
DCN=(DCN.^(-2)).*(DCN<10);
%W=rand(net.N,net.N)<=net.Connectivity;


% Sample synapses
splSynapses.n = 15;
[synOut, synIn] = find(W);
perm = randperm(length(synOut));
rpOut = synOut(perm);
rpIn = synIn(perm);

splSynapses.PostNeurons = rpOut(1:splSynapses.n);
splSynapses.PreNeurons = rpIn(1:splSynapses.n);
splSynapses.IDs = sub2ind(size(ca),splSynapses.PostNeurons,splSynapses.PreNeurons);
splSynapses.ca = zeros(splSynapses.n,Iterations);
splSynapses.xpre = zeros(splSynapses.n,Iterations);
splSynapses.xpost = zeros(splSynapses.n,Iterations);
splSynapses.rho = zeros(splSynapses.n,Iterations);
splSynapses.w = zeros(splSynapses.n,Iterations);



%% Initialization
% %%%%%%%%   SIMULATION PARAMETERS %%%%%%%%  

N_rp=round(t_rp/simu.dt);        % Refractory (in simu.dt)
N_del=round(net.D/simu.dt);          % delay (in simu.dt)

V=V_r*ones(net.N,1);            % Voltage vector
RI=zeros(net.N,N_del);
LS=-(N_del+1)*rand(net.N,1);
allspikes=zeros(1,Iterations);
%ExInput=J*poissrnd(nu_ext*C_ext*simu.dt,net.N,Iterations);
Current=zeros(NCX*NCY,Iterations);

tau_pre = syn.tauDamp;
tau_post = syn.tauDamp;

Rasterplot=zeros(net.N,Iterations);

% %%%%%%% INITIALIZING GIFS %%%%%%%
LWisimu.dths = (5.*(G.Edges.Weight>0) + 0.8.*(G.Edges.Weight<0)).*abs(G.Edges.Weight);
EColors = [0 1 0].*(G.Edges.Weight>0) + [1 0 0].*(G.Edges.Weight<0);
if gif.graph
    figure(1)
    plot(G,'LineWisimu.dth',LWisimu.dths,'EdgeColor',EColors)
    axis tight
    set(gca,'nextplot','replacechildren','visible','off')
    f1 = getframe;
    [im1,map1] = rgb2ind(f1.cdata,256,'nodither');
end

if gif.lapl
    A = W + W';
    D = diag(sum(A,1));
    L_rw = eye(net.N) - D^(-1)*A;
    [eVals, ~] = eig(L_rw);
    
    figure(2)
    spc = sort(diag(eVals));
    plot(1:20, spc(1:20), '+r')
    xlabel('Index')
    ylabel('Eigenvalue')
    title('Eigendecomposition at time 0s')
    set(gca,'nextplot','replacechildren')
    f2 = getframe;
    [im2,map2] = rgb2ind(f2.cdata,256,'nodither');
end

%% Simulation
tic();

if init.strap > 0
    strapIters = init.strap/dt;
    for i=1:strapIters
        V=(1-simu.dt/tau)*V+ExInput(:,1+mod(i-1,1e4))+RI(:,1+mod(i-1,N_del));        % Voltage update
        ca = ca.*exp(-simu.dt/syn.tauCa);
        xpre = 1 - exp(-simu.dt/tau_pre).*(1-xpre);
        xpost = 1 - exp(-simu.dt/tau_post).*(1-xpost);
        spike = (V>=V_t);
        spikingNeurons = find(spike);
        ca(spikingNeurons,:) = ca(spikingNeurons,:) + syn.Cpost.*xpost(spikingNeurons,:);
        ca(:,spikingNeurons) = ca(:,spikingNeurons) + syn.Cpre.*xpre(:,spikingNeurons);
        xpost(spikingNeurons,:) = xpost(spikingNeurons,:)*(1 - syn.dampFactor);
        xpre(:,spikingNeurons) = xpre(:,spikingNeurons)*(1 - syn.dampFactor);
        rho = rho + simu.dt./syn.tauRho .* (syn.gPot.*(syn.rhoMax - rho).*actPot - syn.gDep.*rho.*actDep);
        W = synSign.*transfer(rho, prot);
        V(LS>i-N_del)=V_r;
    end
end

for i=1:Iterations
    if (1+mod(i-1,1e4))==1
        ExInput=J*poissrnd(nu_ext*C_ext*simu.dt,net.N,1e4);
    end
    
    V=(1-simu.dt/tau)*V+ExInput(:,1+mod(i-1,1e4))+RI(:,1+mod(i-1,N_del));        % Voltage update
    ca = ca.*exp(-simu.dt/syn.tauCa);
    xpre = 1 - exp(-simu.dt/tau_pre).*(1-xpre);
    xpost = 1 - exp(-simu.dt/tau_post).*(1-xpost);
    
    Current(:,i)=DCN*V;         % Current to the electrodes
    spike = (V>=V_t);               % Spiking neurons have a "1"
    spikingNeurons = find(spike);
    
    ca(spikingNeurons,:) = ca(spikingNeurons,:) + syn.Cpost.*xpost(spikingNeurons,:);
    ca(:,spikingNeurons) = ca(:,spikingNeurons) + syn.Cpre.*xpre(:,spikingNeurons);
    
    % xpost(spikingNeurons,:) = 0;
    % xpre(:,spikingNeurons) = 0;
    xpost(spikingNeurons,:) = xpost(spikingNeurons,:)*(1 - syn.dampFactor);
    xpre(:,spikingNeurons) = xpre(:,spikingNeurons)*(1 - syn.dampFactor);
    
    actPot = (ca >= syn.tPot).*(W~=0);
    actDep = (ca >= syn.tDep).*(W~=0);
    
    % W = syn.plast(W, spike, simu.dt);
    rho = rho + simu.dt./syn.tauRho .* (syn.gPot.*(syn.rhoMax - rho).*actPot - syn.gDep.*rho.*actDep);
    W = synSign.*transfer(rho, prot);
    
    meanWexc(i+1,1) = mean(W((1/J).*W>0));
    meanWinh(i+1,1) = mean(W((1/J).*W<0));
    
    histRho(:,i) = (1/net.N^2).*histcounts(rho(rho>0),edgesRho);
    histW_exc(:,i) = (1/net.N^2).*histcounts((1/J).*W((1/J).*W>=5e-3),edgesW_exc);
    histW_inh(:,i) = (1/net.N^2).*histcounts((1/J).*W((1/J).*W<=-5e-3),edgesW_inh);
    
    V(LS>i-N_del)=V_r;          % Refractory period. 
    
    % Current generated
    %RI(:,1+mod(i-1,N_del))=W*spike; 
    RI(:,1+mod(i,N_del))=W*spike;
    
    LS(spike)=i;                % Time of last spike
    V(spike)=V_r;              % Reset membrane potential
    
    % Store spike times
    Rasterplot(:,i)=spike;
    allspikes(1,i)=sum(spike); % Each row is (neuron number,spike time)
    
    % Updating synapse sample history
    splSynapses.ca(:,i) =  ca(splSynapses.IDs);
    splSynapses.xpre(:,i) =  xpre(splSynapses.IDs);
    splSynapses.xpost(:,i) =  xpost(splSynapses.IDs);
    splSynapses.rho(:,i) =  rho(splSynapses.IDs);
    splSynapses.w(:,i) = W(splSynapses.IDs);
    
    if mod(i,20)==0
        % Printing network to GIF
        if gif.graph
            G = digraph(W');
            LWisimu.dths = (5.*(G.Edges.Weight>0) + 0.8.*(G.Edges.Weight<0)).*abs(G.Edges.Weight);
            EColors = [0 1 0].*(G.Edges.Weight>0) + [1 0 0].*(G.Edges.Weight<0);
            figure(1)
            plot(G,'LineWisimu.dth',LWisimu.dths,'EdgeColor',EColors)
            f1 = getframe;
            im1(:,:,1,floor(i/20)) = rgb2ind(f1.cdata,map1,'nodither');
        end
        
        % Eigendecomposition to find clusters
        if gif.lapl
            A = abs(W + W');
            D = diag(sum(A,1));
            L_rw = eye(net.N) - D^(-1)*A;
            [eVals, ~] = eig(L_rw);
            figure(2)
            spc = sort(diag(eVals));
            plot(1:20, spc(1:20), '+r')
            xlabel('Index')
            ylabel('Eigenvalue')
            title(strcat('Eigendecomposition at time ', num2str(simu.dt*i,3),'s'))
            f2 = getframe;
            im2(:,:,1,floor(i/20)) = rgb2ind(f2.cdata,map2,'nodither');
        end
    end
    
    progressbar(i/Iterations);
    
end
toc()

G = digraph(W');
LWisimu.dths = (5.*(G.Edges.Weight>0) + 0.8.*(G.Edges.Weight<0)).*abs(G.Edges.Weight);
EColors = [0 1 0].*(G.Edges.Weight>0) + [1 0 0].*(G.Edges.Weight<0);

A = abs(W + W');
D = diag(sum(A,1));
L_rw = eye(net.N) - D^(-1)*A;
[eVals, ~] = eig(L_rw);

filter = repmat(gausswin(100,2.5e-2),N,1);
rateEst = (1/simu.dt).*conv(Rasterplot, filter);
edgesRates = 0:1:200;
for i=1:Iterations
    histRates(:,i) = histcounts(rateEst(:,i),edgesRates);
end


%% Correlation analysis
splSynapses.corr = zeros();

%% Creating graph for visualization
if gif.graph
    imwrite(im1, map1, strcat(env.outputsRoot, 'Figures/Network/sampleGraph_randinit.gif'), 'DelayTime',0, 'LoopCount',inf)
end

if gif.lapl
    imwrite(im2,map2, strcat(env.outputsRoot, 'Figures/Network/specClust_asym.gif'), 'DelayTime',0, 'LoopCount',inf)
end

%% Plotting network stats

if plt.all.raster == 1
    figure(1)
    [I1,I2] = find(Rasterplot);
    plot(I2,I1,'.','MarkerSize',1)
    title('Spiking activity in neural population')
    
elseif plt.all.raster == 2
    rasterSnaps = zeros(net.N, plt.timeSpl.n*ceil(plt.timeSpl.dur/simu.dt) + (plt.timeSpl.n-1)*plt.timeSpl.inter);
    totActSnaps = zeros(1, plt.timeSpl.n*ceil(plt.timeSpl.dur/simu.dt) + (plt.timeSpl.n-1)*plt.timeSpl.inter);
    for tSplID = 1:plt.timeSpl.n
        rasterSnaps(:, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ...
            = Rasterplot(:,1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));           

        rasterSnaps(:, 1 + tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter : plt.timeSpl.inter + tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ... 
            = 1;
    end    
    totActSnaps = sum(rasterSnaps);
    for tSplID = 1:plt.timeSpl.n
        totActSnaps(1, 1 + tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter : plt.timeSpl.inter + tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) = 0;
    end
    figure(1)
    ax1 = subplot(2,1,1);
    imagesc(rasterSnaps)
    ax2 = subplot(2,1,2);
    bar(totActSnaps)
    ax1.Position(1,2) = ax1.Position(1,2) - 0.7*ax2.Position(1,4);
    ax1.Position(1,4) = 1.7*ax1.Position(1,4);
    ax2.Position(1,4) = 0.3*ax2.Position(1,4);
end

if plt.spl.ca
    figure(2)
    imagesc(splSynapses.ca)
    title('Synaptic calcium actvivity in sample synapses')
    colorbar
end

if plt.spl.rho
    figure(3)
    imagesc(splSynapses.rho)
    title('Phosphorylation state at sample synapses')
    colorbar
end

if plt.spl.w
    splSynapses.wHist = synSign(splSynapses.IDs).*transfer(splSynapses.rho, prot);
    figure(4)
    imagesc(splSynapses.wHist)
    title('Synaptic weight at sample synapses')
    colorbar
end

splSynapses.stats = cat(2, linspace(1,splSynapses.n,splSynapses.n)', splSynapses.PreNeurons, splSynapses.PostNeurons, splSynapses.w(:,1), splSynapses.w(:,end))

if plt.spl.pres == 1
    splSynapses.pres = zeros(3*splSynapses.n, Iterations);
    for i=1:splSynapses.n
        splSynapses.pres(3*(i-1)+1,:) = 100*Rasterplot(splSynapses.PreNeurons(i,1),:);
        splSynapses.pres(3*(i-1)+2,:) = 100*Rasterplot(splSynapses.PostNeurons(i,1),:);
        splSynapses.pres(3*(i-1)+3,:)= (1/J).*synSign(splSynapses.IDs(i)).*splSynapses.rho(i,:);
    end
    figure(5)
    imagesc(splSynapses.pres)
    colorbar
elseif plt.spl.pres == 2
    splSynapses.pres = zeros(5*floor(splSynapses.n/2), Iterations);
    for i=1:splSynapses.n
        splSynapses.pres(5*(i-1)+1,:) = Rasterplot(splSynapses.PreNeurons(i,1),:);
        splSynapses.pres(5*(i-1)+2,:) = Rasterplot(splSynapses.PostNeurons(i,1),:);
        splSynapses.pres(5*(i-1)+3,:)= splSynapses.ca(i,:);
        splSynapses.pres(5*(i-1)+4,:)= (1/(J*syn.rhoMax)).*synSign(splSynapses.IDs(i)).*splSynapses.rho(i,:);
        splSynapses.pres(5*(i-1)+5,:)= (1/J).*splSynapses.w(i,:);
    end
    figure(5)
    imagesc(splSynapses.pres)
    colorbar
elseif plt.spl.pres == 3
    splSynapses.pres = zeros(5*floor(splSynapses.n/2), plt.timeSpl.n*ceil(plt.timeSpl.dur/simu.dt) + (plt.timeSpl.n-1)*plt.timeSpl.inter);
    for tSplID = 1:plt.timeSpl.n
        for i=1:splSynapses.n
            splSynapses.pres(5*(i-1)+1, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ...
                = Rasterplot(splSynapses.PreNeurons(i,1),1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));           
            
            splSynapses.pres(5*(i-1)+2, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ... 
                = Rasterplot(splSynapses.PostNeurons(i,1),1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));
            
            splSynapses.pres(5*(i-1)+3, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ...
                = splSynapses.ca(i,1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));
            
            splSynapses.pres(5*(i-1)+4, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ...
                = (1/(J*syn.rhoMax)).*synSign(splSynapses.IDs(i)).*splSynapses.rho(i,1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));
            
            splSynapses.pres(5*(i-1)+5, 1+(tSplID-1)*(ceil(plt.timeSpl.dur/simu.dt)+plt.timeSpl.inter):tSplID*ceil(plt.timeSpl.dur/simu.dt)+(tSplID-1)*plt.timeSpl.inter) ...
                = (1/J).*splSynapses.w(i,1+(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1):(tSplID-1)/(plt.timeSpl.n-1)*(Iterations-ceil(plt.timeSpl.dur/simu.dt)-1)+ceil(plt.timeSpl.dur/simu.dt));
        end
    end
    figure(5)
    imagesc(splSynapses.pres)
    colorbar
end

if plt.spl.hist
    tickList = ceil(nbins.*(0.1:0.1:1));
    figure(6)
    ax1 = subplot(2,1,1);
    imagesc(log(histW_exc));
    set(gca,'YDir','normal')
    title('Evolution of weight distribution for excitatory synapses')
    xlabel('Time')
    ylabel('Synaptic weight')
    yticks(tickList)
    yticklabels(edgesW_exc(1, tickList))
    colorbar
    Wexc_hStep = edgesW_exc(2) - edgesW_exc(1);
    valsWexc = edgesW_exc + Wexc_hStep;
    valsWexc = repmat(valsWexc(:,1:end-1)',1,Iterations);
    sumWexc = sum(valsWexc.*histW_exc);
    ax2 = subplot(2,1,2);
    bar(edgesW_exc(2:end), histW_exc(:,end))
    ax1.Position(1,2) = ax1.Position(1,2) - 0.5*ax2.Position(1,4);
    ax1.Position(1,4) = 1.5*ax1.Position(1,4);
    ax2.Position(1,4) = 0.5*ax2.Position(1,4);
    
    figure(7)
    ax1 = subplot(2,1,1);
    imagesc(log(histW_inh));
    set(gca,'YDir','normal')
    title('Evolution of weight distribution for inhibitory synapses')
    xlabel('Time')
    ylabel('Synaptic weight')
    yticks(tickList)
    yticklabels(edgesW_inh(1, tickList))
    colorbar
    Winh_hStep = edgesW_inh(2) - edgesW_inh(1);
    valsWinh = edgesW_inh + Winh_hStep;
    valsWinh = repmat(valsWinh(:,1:end-1)',1,Iterations);
    sumWinh = sum(valsWinh.*histW_inh);
    ax2 = subplot(2,1,2);
    bar(edgesW_inh(2:end), histW_inh(:,end))
    ax1.Position(1,2) = ax1.Position(1,2) - 0.5*ax2.Position(1,4);
    ax1.Position(1,4) = 1.5*ax1.Position(1,4);
    ax2.Position(1,4) = 0.5*ax2.Position(1,4);
    
    figure(8)
    ax1 = subplot(2,1,1);
    imagesc(log(histRho));
    set(gca,'YDir','normal')
    title('Evolution of phosphorylation distribution (all synapses)')
    xlabel('Time')
    ylabel('Phosphorylation level')
    yticks(tickList)
    yticklabels(edgesRho(1, tickList))
    colorbar
    ax2 = subplot(2,1,2);
    bar(edgesRho(2:end), histRho(:,end))
    ax1.Position(1,2) = ax1.Position(1,2) - 0.5*ax2.Position(1,4);
    ax1.Position(1,4) = 1.5*ax1.Position(1,4);
    ax2.Position(1,4) = 0.5*ax2.Position(1,4);
    
    % sprintf('Excitatory: %0.3f - Inhibitory: %0.3f - Total: %0.3f', sumWexc(1,end)/J, -sumWinh(1,end)/J, (sumWexc(1,end) + sumWinh(1,end))/J)
    figure(9)
    ax1 = subplot(2,1,1);
    imagesc(log(histRates));
    set(gca,'YDir','normal')
    title('Evolution of firing rates distribution')
    xlabel('Time')
    ylabel('Firing rate')
    yticks(tickList)
    yticklabels(edgesRho(1, tickList))
    colorbar
    ax2 = subplot(2,1,2);
    bar(edgesRates(2:end), histRates(:,end))
    ax1.Position(1,2) = ax1.Position(1,2) - 0.5*ax2.Position(1,4);
    ax1.Position(1,4) = 1.5*ax1.Position(1,4);
    ax2.Position(1,4) = 0.5*ax2.Position(1,4);
end

if plt.spl.phase == 1
    figure(10)
    plot((1/meanWexc(2,1)).*meanWexc(2:end,1), (1/meanWinh(2,1)).*meanWinh(2:end,1), '-')
    title('Evolution of average synaptic weights')
    xlabel('Relative mean excitatory weight')
    ylabel('Relative mean inhibitory weight')
elseif plt.spl.phase == 2
    figure(10)
    plot((1/meanWexc(2,1)).*meanWexc(2:end,1), -meanWinh(2:end,1)./meanWexc(2:end,1), '-')
    for i=1:20:201
        text((1/meanWexc(2,1)).*meanWexc(1+i,1), -meanWinh(1+i,1)./meanWexc(1+i,1),num2str(1+i),'Color','r')
    end
    for i=301:100:1001
        text((1/meanWexc(2,1)).*meanWexc(1+i,1), -meanWinh(1+i,1)./meanWexc(1+i,1),num2str(1+i),'Color','r')
    end
    for i=2001:1000:10001
        text((1/meanWexc(2,1)).*meanWexc(1+i,1), -meanWinh(1+i,1)./meanWexc(1+i,1),num2str(1+i),'Color','r')
    end
    title('Evolution of average synaptic weights')
    xlabel('Relative mean excitatory weight')
    ylabel('Relative mean inhibitory weight')
    % ylim([min(3, min(-meanWinh(2:end,1)./meanWexc(2:end,1))) max(8, max(-meanWinh(2:end,1)./meanWexc(2:end,1)))])
    
    SRtoAI_thr = refline([0 4.2]);
    SRtoAI_thr.Color = 'r';

    AItoSI_thr = refline([0 5.3]);
    AItoSI_thr.Color = 'g';
end