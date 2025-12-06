% MDM_PhaseSpace_Analysis.m
% Minimal Decoupling Model (MDM) - Basin of Attraction Analysis
%
% DESCRIPTION:
% This script simulates the "Thermostat Economy" (Closed-Loop Wage Subsidy)
% across a grid of initial conditions to map the "Basin of Attraction."
% It visualizes which economic starting states lead to stabilization (High Participation)
% and which lead to a "Subsidy Trap" or collapse.
%
% KEY PARAMETERS:
% - phi (Friction): 3.0 (Significant investment adjustment costs)
% - P_target (Control): 0.70 (Target Participation Rate)
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

%% 2. Define Simulation Grid
% We grid the initial conditions to explore the state space.
% K (Capital), R (Robots), P (Participation)
K_vals = [2, 3, 4];
R_vals = [0.5, 1, 2];
P_vals = [0.5, 0.6, 0.7];

[K_g, R_g, P_g] = ndgrid(K_vals, R_vals, P_vals);
scenarios = [K_g(:), K_g(:), R_g(:), P_g(:)]; % KH and KL initialized equally

disp(['Running ', num2str(size(scenarios,1)), ' simulations across phase space...']);

%% 3. Setup Visualization
figure('Name', 'MDM Basin of Attraction', 'Position', [100, 100, 1400, 600]);

% Left Plot: Social Contract (Wage vs Participation)
ax1 = subplot(1,2,1); hold on; grid on;
xlabel('Effective Wage (w_{eff})'); ylabel('Participation (P)');
title('Social Contract Phase Space');
xline(p.wbar, 'r:', 'Survival Wage');
yline(p.P_target, 'k--', 'Target P');
ylim([0.3, 1.05]);

% Right Plot: Fiscal Reality (GDP vs Subsidy)
ax2 = subplot(1,2,2); hold on; grid on;
xlabel('Total GDP (Y)'); ylabel('Subsidy Fraction (S)');
title('Fiscal Phase Space (The Graduation Path)');
yline(p.S_max, 'r:', 'Max Cap');

%% 4. Simulation Loop
Tspan = [0 60];
opts = odeset('RelTol',1e-7,'AbsTol',1e-9);

% Wrapper function for ode45
wrapper = @(t,x) get_xdot(t,x,p);

for i = 1:size(scenarios, 1)
    % Construct Initial State x0
    % [KH, KL, R, theta, P, S_integral]
    x0 = [scenarios(i,1); scenarios(i,2); scenarios(i,3); 0.45; scenarios(i,4); 0.0];
    
    [t, x] = ode45(wrapper, Tspan, x0, opts);
    
    % Reconstruct Derived Variables (Trajectories)
    len = length(t);
    w_eff_traj = zeros(len,1);
    S_used_traj = zeros(len,1);
    Y_traj = zeros(len,1);
    
    for k = 1:len
        out = mdm_dynamics_friction(t(k), x(k,:)', [], p);
        w_eff_traj(k) = out.w_eff;
        S_used_traj(k) = out.S_used;
        Y_traj(k) = out.Y;
    end
    
    % --- Outcome Classification (Color Logic) ---
    final_P = x(end, 5);
    final_S = S_used_traj(end);
    
    if final_P > 0.68 && final_S < 0.05
        % SUCCESS: High P, Low Subsidy -> Green/Teal
        line_color = [0, 0.6, 0.3, 0.4]; 
    elseif final_S > 0.45
        % TRAPPED: Hit the Subsidy Cap -> Red
        line_color = [0.8, 0, 0, 0.3]; 
    else
        % PURGATORY: Grey
        line_color = [0.5, 0.5, 0.5, 0.2];
    end
    
    % Plot Trajectories
    plot(ax1, w_eff_traj, x(:,5), 'Color', line_color, 'LineWidth', 1.0);
    plot(ax2, Y_traj, S_used_traj, 'Color', line_color, 'LineWidth', 1.0);
    
    % Mark Endpoints
    if final_S > 0.45
        plot(ax1, w_eff_traj(end), x(end,5), 'rx', 'MarkerSize', 8);
        plot(ax2, Y_traj(end), S_used_traj(end), 'rx', 'MarkerSize', 8);
    else
        plot(ax1, w_eff_traj(end), x(end,5), 'gx', 'MarkerSize', 8);
        plot(ax2, Y_traj(end), S_used_traj(end), 'gx', 'MarkerSize', 8);
    end
end

disp('Simulation Complete.');

%% ===================== Local Functions ===================================

function dx = get_xdot(t,x,p)
    out = mdm_dynamics_friction(t,x,[],p);
    dx = out.xdot;
end

function out = mdm_dynamics_friction(~, x, ~, p)
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
    % Hard Constraints
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
end

function val = nth_output(N, fcn, arg)
    [outs{1:N}] = fcn(arg);
    val = outs{N};
end