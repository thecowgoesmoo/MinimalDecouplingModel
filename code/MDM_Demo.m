% MDM_Demo.m
% Minimal Decoupling Model (MDM) - Single Trajectory Demonstration
%
% DESCRIPTION:
% This script runs a single time-series simulation of the "Thermostat Economy."
% It demonstrates how a Closed-Loop PI Controller (Wage Subsidies) can 
% stabilize labor participation during a transition to high automation, 
% bridging the "Valley of Death" until capital accumulation restores 
% the natural marginal product of labor.
%
% SCENARIO:
% - Investment Friction (phi = 3.0)
% - Target Participation (P = 0.70)
% - Starting from 2025 Baseline Conditions
%
% AUTHORS: Richard Moore, ChatGPT-5, Gemini 3
% LICENSE: MIT
% REPO: https://github.com/thecowgoesmoo/MinimalDecouplingModel

clear; clc; close all;

%% 1. Define Model Parameters (The "Goldilocks" Set)
p = struct();
% Technology & Production
p.AH = 1.35; p.AL = 1.05; p.alpha = 0.38; p.beta = 0.30;
p.sigma = 1.35; p.mu = 0.55; p.psi_hi = 5.0;
p.deltaK = 0.06; p.deltaR = 0.25;

% Labor Dynamics
p.N = 1.0; p.wbar = 2.10; 
p.eta = 0.5;      % Max entry speed
p.deltaP = 0.5;   % Max exit speed
p.chi = 0.45;     % Skill exclusion
p.gamma = 1.5;
p.lambda_theta = 0.50; p.kappa_theta = 0.20;

% Financials & Control
p.tau = 0.0; p.q0 = 1.0;
p.iotaH = 0.20; p.iotaL = 0.15; p.iotaR = 0.45;
p.eps_fd = 1e-6;

% Reality & Control Factors
p.phi = 3.0;        % Investment Friction (Reality Check)
p.P_target = 0.70;  % Target Participation
p.Kp = 0.5;         % Proportional Gain
p.Ki = 0.10;        % Integral Gain
p.S_max = 0.50;     % Subsidy Cap (50% of GDP)

%% 2. Initial State & Simulation
% x = [KH, KL, R, theta, P, S_integral]
% Initializing roughly at current US macro proxies (normalized)
x0 = [2.8; 2.7; 1.2; 0.45; 0.627; 0.0];

Tspan = [0 50]; % Simulate 50 years
opts = odeset('RelTol',1e-7,'AbsTol',1e-9);

% Wrapper function for ode45
wrapper = @(t,x) get_xdot(t,x,p);

disp('Running simulation...');
[t, x] = ode45(wrapper, Tspan, x0, opts);

% Reconstruct Derived Variables for Plotting
len = length(t);
Y = zeros(len,1); 
w_market = zeros(len,1); 
w_effective = zeros(len,1);
S_total = zeros(len,1); 
Eff_R = zeros(len,1); % Investment Efficiency Tracking

for i = 1:len
    out_i = mdm_dynamics(t(i), x(i,:)', [], p);
    Y(i) = out_i.Y;
    w_market(i) = out_i.w;
    w_effective(i) = out_i.w_eff;
    S_total(i) = out_i.S_used;
    Eff_R(i) = out_i.eff_R;
end

P = x(:,5);

%% 3. Visualization
figure('Name', 'Thermostat Economy Demo', 'Position', [100, 100, 1200, 800]);

% Panel 1: Participation (The Goal)
subplot(2,2,1); 
plot(t, P, 'b-', 'LineWidth', 2); hold on;
yline(p.P_target, 'r--', 'Target (0.7)'); 
ylim([0.4, 1.0]); grid on;
title('Participation Rate (P)'); ylabel('Rate');
legend('Actual P', 'Target P', 'Location', 'SouthEast');

% Panel 2: The Cost (Subsidy)
subplot(2,2,2); 
plot(t, S_total * 100, 'm-', 'LineWidth', 2); grid on;
yline(p.S_max*100, 'r:', 'Hard Cap');
title('Required Subsidy (% of GDP)'); ylabel('%'); 
xlabel('Year');

% Panel 3: The Bridge (Wages)
subplot(2,2,3); 
plot(t, w_market, 'k--', 'LineWidth', 1.5); hold on;
plot(t, w_effective, 'g-', 'LineWidth', 2);
yline(p.wbar, 'r:', 'Survival Wage');
legend('Market Wage', 'Effective (w/ Subsidy)', 'w_{bar}', 'Location','NorthWest'); 
title('The Wage Gap Bridge'); grid on; 
ylim([0, 8]); 

% Panel 4: The Outcome (GDP & Friction)
subplot(2,2,4); 
yyaxis left; 
plot(t, Y, 'k-', 'LineWidth', 2); 
ylabel('Total GDP (Y)');
yyaxis right; 
plot(t, Eff_R, 'c-.', 'LineWidth', 1.5); 
ylabel('Inv. Efficiency \eta');
title('Growth vs. Friction'); xlabel('Year'); grid on;

disp('Demo Complete.');

%% ===================== Local Functions ===================================

function dx = get_xdot(t,x,p)
    out = mdm_dynamics(t,x,[],p);
    dx = out.xdot;
end

function out = mdm_dynamics(~, x, ~, p)
    % Unpack States
    KH = x(1); KL = x(2); R = x(3); theta = x(4); P = x(5); 
    S_integral = x(6);
    
    % --- 1. Production Physics ---
    psi = 1 + (p.psi_hi - 1) * (1 - min(max(theta,0),1));
    L = max(0, min(1, P)) * p.N;
    rho = (p.sigma - 1) / p.sigma;

    % Nested helper functions for Marginal Products
    function [YH, MPLH] = get_H_stats(LH)
        Aagg = ((1-p.mu)*max(LH,1e-12)^rho + p.mu*(psi*R)^rho)^(1/rho);
        YH = p.AH * max(KH,1e-12)^p.alpha * Aagg;
        dS = (1-p.mu)*max(LH,1e-12)^(rho-1) * Aagg^(1-rho); 
        MPLH = p.AH * max(KH,1e-12)^p.alpha * dS;
    end
    function [YL, MPLL] = get_L_stats(LL)
        YL = p.AL * max(KL,1e-12)^p.beta * max(LL,1e-12)^(1-p.beta);
        MPLL = (1-p.beta)*p.AL*max(KL,1e-12)^p.beta * max(LL,1e-12)^(-p.beta);
    end

    % Solve Labor Allocation (MPL_H = MPL_L)
    if L <= 1e-9
        YH=0; YL=0; w=0; LH=0; LL=0;
    else
        mpl_h = @(h) nth_output(2, @get_H_stats, h);
        mpl_l = @(l) nth_output(2, @get_L_stats, l);
        F = @(h) mpl_h(h) - mpl_l(L - h);
        try LH = fzero(F, [0, L]); catch, LH=L/2; end 
        LH = max(0,min(L,LH)); LL = L - LH;
        [YH, MPLH] = get_H_stats(LH); [YL, MPLL] = get_L_stats(LL);
        w = 0.5*(MPLH+MPLL);
    end
    Y = YH + YL;

    % --- 2. PI Controller (The Thermostat) ---
    error = p.P_target - P;
    S_prop = p.Kp * error;
    S_raw = S_prop + S_integral;
    S_used = max(0, min(p.S_max, S_raw));
    
    % Anti-Windup Logic
    if (S_raw >= p.S_max && error > 0) || (S_raw <= 0 && error < 0)
        dS_dt = 0; 
    else
        dS_dt = p.Ki * error;
    end

    % --- 3. Dynamics Update ---
    % Apply Subsidy to Effective Wage
    w_effective = w + (S_used * Y) / max(P * p.N, 1e-3);

    % Participation (Hysteresis)
    drive = tanh(2 * (w_effective - p.wbar));
    if drive > 0, dP_term = p.eta * max(P,0) * drive;
    else,         dP_term = p.deltaP * max(P,0) * drive;
    end
    excl = p.chi * (p.mu*psi)^p.gamma * (1 - min(max(theta,0),1)) * max(P,0);
    dP = dP_term - excl;
    if P>=1 && dP>0, dP=0; end
    if P<=0 && dP<0, dP=0; end

    % Diffusion
    sL_H = (LH>0)*(w*LH/max(YH,1e-12));
    press = max(0, 1 - min(max(sL_H,0),1));
    dtheta = p.lambda_theta*(1-min(max(theta,0),1))*press - p.kappa_theta*min(max(theta,0),1);
    
    % Capital Accumulation with Friction
    Pi_H = max(YH - w*LH, 0); Pi_L = max(YL - w*LL, 0); Pi = max(Y - w*L, 0);
    
    IH_gross = p.iotaH*Pi_H;
    IL_gross = p.iotaL*Pi_L;
    IR_gross = p.iotaR*Pi;

    % Investment Efficiency Factor
    eff_H = 1 / (1 + p.phi * (IH_gross / max(KH, 1e-3)));
    eff_L = 1 / (1 + p.phi * (IL_gross / max(KL, 1e-3)));
    eff_R = 1 / (1 + p.phi * (IR_gross / max(R,  1e-3)));

    dKH = IH_gross * eff_H - p.deltaK*KH;
    dKL = IL_gross * eff_L - p.deltaK*KL;
    dR  = IR_gross * eff_R - p.deltaR*R;

    out.xdot = [dKH; dKL; dR; dtheta; dP; dS_dt];
    out.Y = Y; out.w = w; out.w_eff = w_effective; out.S_used = S_used;
    out.eff_R = eff_R;
end

function val = nth_output(N, fcn, arg)
    [outs{1:N}] = fcn(arg);
    val = outs{N};
end