%DEMO_FLEXGRID_SDM_BLOCKING  Why flex-grid and space-division multiplexing (SDM) change blocking.
%
%   A minimal, self-contained illustration of the core idea behind the
%   study: in a transparent optical network a lightpath must occupy the
%   SAME contiguous block of spectrum on EVERY fibre it crosses (spectrum
%   continuity + contiguity), and in a multi-core fibre also the SAME core
%   (core continuity). How the spectrum is quantised, and how many spatial
%   channels exist, therefore decides how much traffic is blocked.
%
%   The script runs a small dynamic routing-and-spectrum-assignment (RSA)
%   simulation on a GENERIC 6-node mesh and compares three line systems
%   with the same 1 THz of spectrum per core:
%
%     1. Fixed grid, 50 GHz ITU channels, single-core fibre
%     2. Flex-grid, 12.5 GHz slots (ITU-T G.694.1), single-core fibre
%     3. Flex-grid, 12.5 GHz slots, 3-core multi-core fibre (SDM)
%
%   Routing is hop-count shortest path, spectrum assignment is First-Fit,
%   and all three cases see exactly the same traffic (common random
%   numbers), so differences come from the line system alone.
%
%   This is a textbook-level demonstration. The topology, traffic mix,
%   load range, routing and assignment rules are deliberately generic and
%   are NOT the network, models, parameters or algorithms of the study.
%   Node (OXC / transceiver) limits and physical-layer impairments are
%   intentionally left out.
%
%   Requirements: base MATLAB (R2026a) or GNU Octave 8, no toolboxes.
%   Output: one figure, also saved to ../docs/figures/demo_flexgrid_sdm.png
%
%   (c) Ikhlas Sabilly. All rights reserved. See LICENSE.

clear; close all;

%% Generic network and traffic (illustrative values) ----------------------
E = [1 2; 1 3; 2 3; 2 4; 3 5; 4 5; 4 6; 5 6];  % undirected fibre links
N = 6;
slot_GHz   = 12.5;                    % flex-grid granularity
n_slots    = 80;                      % 80 x 12.5 GHz = 1 THz per core (kept small for speed)
bw_GHz     = [37.5 62.5 75];          % required optical bandwidth per demand
bw_prob    = [0.4 0.4 0.2];
loads      = 30:30:300;              % offered load [Erlang] (mean IAT = 1)
n_req      = 12000;                   % requests per load point
n_warm     = 2000;                    % warm-up requests excluded from statistics

cases = struct('name', {'Fixed grid 50 GHz, 1 core', ...
                        'Flex-grid 12.5 GHz, 1 core', ...
                        'Flex-grid 12.5 GHz, 3-core MCF (SDM)'}, ...
               'grid', {50, 12.5, 12.5}, ...
               'cores', {1, 1, 3});

%% Directed links and hop-count shortest paths (Floyd-Warshall) ----------
L   = [E; fliplr(E)];                 % directed link list
nL  = size(L,1);
lid = zeros(N); for k = 1:nL, lid(L(k,1), L(k,2)) = k; end
D = inf(N); D(1:N+1:end) = 0; nxt = zeros(N);
for k = 1:nL, D(L(k,1),L(k,2)) = 1; nxt(L(k,1),L(k,2)) = L(k,2); end
for i = 1:N, nxt(i,i) = i; end
for m = 1:N
    for i = 1:N
        for j = 1:N
            if D(i,m) + D(m,j) < D(i,j)
                D(i,j) = D(i,m) + D(m,j); nxt(i,j) = nxt(i,m);
            end
        end
    end
end
path_links = cell(N);
for s = 1:N
    for d = 1:N
        u = s; pl = [];
        while u ~= d, v = nxt(u,d); pl(end+1) = lid(u,v); u = v; end %#ok<AGROW>
        path_links{s,d} = pl;
    end
end

%% Simulation ---------------------------------------------------------------
BBP = zeros(numel(cases), numel(loads));     % bandwidth blocking probability
for il = 1:numel(loads)
    % identical traffic for every case (common random numbers)
    rng(il);
    t_arr = cumsum(-log(rand(n_req,1)));             % Poisson arrivals, mean IAT 1
    t_hold = -log(rand(n_req,1)) * loads(il);        % exponential holding
    src = randi(N, n_req, 1); dst = randi(N-1, n_req, 1);
    dst(dst >= src) = dst(dst >= src) + 1;           % src ~= dst
    u   = rand(n_req,1);
    cls = 1 + (u > bw_prob(1)) + (u > bw_prob(1) + bw_prob(2));
    bw  = bw_GHz(cls(:)).';  bw = bw(:);

    for c = 1:numel(cases)
        g    = cases(c).grid / slot_GHz;              % slots per grid unit
        nC   = cases(c).cores;
        S    = false(nL, n_slots, nC);                % spectrum state
        act  = zeros(0, 5);                           % [t_dep core s0 n req]
        offered = 0; blocked = 0;
        for r = 1:n_req
            t = t_arr(r);
            % release finished lightpaths
            done = act(:,1) <= t;
            for q = find(done).'
                pl = path_links{src(act(q,5)), dst(act(q,5))};
                S(pl, act(q,3):act(q,3)+act(q,4)-1, act(q,2)) = false;
            end
            act(done,:) = [];
            % slots needed on this grid
            n  = g * ceil(bw(r) / cases(c).grid - 1e-9);
            pl = path_links{src(r), dst(r)};
            s0 = 0; core = 0;
            for k = 1:nC                               % core-first, then First-Fit
                free = ~any(S(pl,:,k), 1);            % continuity: free on every link
                fits = conv(double(free), ones(1,n), 'valid') == n;   % contiguity
                fits(mod(0:numel(fits)-1, g) ~= 0) = false;  % fixed grid: aligned starts only
                s = find(fits, 1);                    % First-Fit
                if ~isempty(s), s0 = s; core = k; break; end
            end
            if r > n_warm, offered = offered + bw(r); end
            if s0 == 0
                if r > n_warm, blocked = blocked + bw(r); end
            else
                S(pl, s0:s0+n-1, core) = true;
                act(end+1,:) = [t + t_hold(r), core, s0, n, r]; %#ok<AGROW>
            end
        end
        BBP(c, il) = blocked / offered;
    end
    fprintf('load %4d Erl done\n', loads(il));
end

%% Plot ---------------------------------------------------------------------
fig = figure('Color', 'w', 'Position', [100 100 760 440]);
mk = {'s-', 'o-', 'd-'};
for c = 1:numel(cases)
    semilogy(loads, max(BBP(c,:), 1e-5), mk{c}, 'LineWidth', 2); hold on;
end
grid on; box on;
xlabel('Offered load (Erlang)');
ylabel('Bandwidth blocking probability');
title('Fixed grid vs flex-grid vs flex-grid + SDM (generic 6-node mesh; zero shown at 10^{-5})');
legend({cases.name}, 'Location', 'southeast');
ylim([1e-5 1]);

outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'docs', 'figures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
print(fig, fullfile(outDir, 'demo_flexgrid_sdm.png'), '-dpng', '-r200');

fprintf('\nLoad (Erl)   Fixed-50G   Flex-12.5G   Flex+SDM(3 cores)\n');
for il = 1:numel(loads)
    fprintf('   %4d     %9.4f   %10.4f   %10.4f\n', loads(il), BBP(1,il), BBP(2,il), BBP(3,il));
end
