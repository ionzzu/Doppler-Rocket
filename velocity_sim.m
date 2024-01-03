% initial values
h = 0; % altitude
H = []; % height above ground
V = 0; % velocity

% constants
tf = 100; % time at end of sim
ts = .01; % sim time step
Cd_drogue = .80; % coefficient drag drogue
Cd_main = .80; % coefficient drag main
A_drogue = 1.267; % area drogue (m^2) ------------------------CHANGE FOR 2019
A_main = 2.488; % area main (m^2) ------------------------CHANGE FOR 2019
g = 9.81; % acceleration due to gravity
mi = 14.994; % take off weight (kg)
A = 0.008495; % cross-sectional area of vehicle (m^2) ------------------------CHANGE FOR 2019
L = .0065; % temp drop per meter as we increase altitude (K/m)
T0 = 273.15+36; % temp at ground (K)
M = .0289644; % molar mass dry air
R0 = 8.31447; % ideal gas constant
Rs = 287.058; % specific gas constant
G = 6.67408*10^-11; % gravitational constant
m_earth = 5.972*10^24; % mass earth
r_earth = 6.371*10^6; % radius earth
P0 = 86650; % pressure at 1293.876 m above sea level
% P0 = 101325; sea level

% functions
Cd_Data =[0, 0.41; % drag as a function of velocity for vehicle from CFD
     32.36975896, 0.41;
     64.73951793, 0.4358;
     97.10927689, 0.4382;
     129.4790359, 0.4294;
     161.8487948, 0.4245;
     194.2185538, 0.4156;
     226.5883127, 0.4112;
     258.9580717, 0.4120;
     291.3278307, 0.4101;
     323.6975896, 0.4182];
Cd = @(x) interp1(Cd_Data(:,1), Cd_Data(:,2), x, 'PCHIP', 'extrap'); 

Fm_Data = [0, 0; % thrust as a function of time for motor from motor spec
      0.011, 1195.177;
      0.024, 2029.903;
      0.037, 2380.868;
      0.05, 2542.122;
      0.1, 2570.578;
      0.15, 2561.093;
      0.2, 2523.151;
      0.25, 2485.208;
      0.3, 2523.151;
      0.35, 2570.578;
      0.4, 2674.919;
      0.5, 2912.057;
      0.6, 3073.311;
      0.7, 3073.311;
      0.8, 3101.768;
      0.9, 3092.282;
      1, 3092.282;
      1.1, 2959.485;
      1.186, 2807.716;
      1.227, 2437.781;
      1.27, 2257.556;
      1.3, 2162.701;
      1.4, 1991.961;
      1.5, 1878.135;
      1.6, 1792.765;
      1.7, 1688.424;
      1.8, 1612.54;
      1.9, 1584.083;
      2, 1536.656;
      2.048, 1498.714;
      2.084, 1403.858;
      2.102, 1166.72;
      2.134, 796.784;
      2.186, 455.305;
      2.237, 237.138;
      2.3, 94.855;
      2.4, 0];
Fm = @(x) interp1(Fm_Data(:,1), Fm_Data(:,2), x, 'PCHIP', 0);

mp_Data = [0, 0; % mass loss as a function of time from motor assuming constant specific impulse
      0.011, 0.003242863;
      0.024, 0.013584456;
      0.037, 0.027728106;
      0.05, 0.043514246;
      0.1, 0.106569887;
      0.15, 0.1698595;
      0.2, 0.232564189;
      0.25, 0.294332978;
      0.3, 0.356101767;
      0.35, 0.418923436;
      0.4, 0.48361688;
      0.5, 0.621426786;
      0.6, 0.76906354;
      0.7, 0.92067783;
      0.8, 1.072994049;
      0.9, 1.225778211;
      1, 1.378328389;
      1.1, 1.527602959;
      1.186, 1.649942591;
      1.227, 1.702991215;
      1.27, 1.752792306;
      1.3, 1.785501693;
      1.4, 1.887981743;
      1.5, 1.983442609;
      1.6, 2.07399005;
      1.7, 2.159858028;
      1.8, 2.241280525;
      1.9, 2.320129318;
      2, 2.397106335;
      2.048, 2.433044551;
      2.084, 2.458818984;
      2.102, 2.470232171;
      2.134, 2.485730519;
      2.186, 2.501790394;
      2.237, 2.51050119;
      2.3, 2.51566028;
      2.4, 2.518];
  mp = @(x) interp1(mp_Data(:,1), mp_Data(:,2), x, 'PCHIP', 2.518);
  
  T = @(x) T0 - x*L; % input: altitude
  P = @(x) P0*(1-L*x/T0)^(g*M/R0/L); % input: altitude
  rho = @(x) P(x)/Rs/T(x); % input: altitude
  Fd = @(x,y).5*rho(x)*y^2*Cd(abs(y))*A*sign(y); % input: altitude, velocity
  Fd_drogue = @(x,y).5*rho(x)*y^2*Cd_drogue*A_drogue*sign(y);
  Fd_main = @(x,y).5*rho(x)*y^2*Cd_main*A_main*sign(y);
  Fg = @(x,y) G*x*m_earth/(r_earth+y).^2; % input: mass, altitude 
  %% simulation
  V_data = [];
  A_data = [];
  G_data = [];
  t = .002; % start time; if we start at zero the rocket falls and ends sim
  time = [];
  Fd_data = [];
  drogue_deployed = 0;
  main_deployed = 0;
  while (h >= 0) % sim loop
      if drogue_deployed && main_deployed
         F = Fm(t)-Fg(mi-mp(t), h)-Fd_drogue(h, V)-Fd_main(h,V)-Fd(h, V); 
      elseif drogue_deployed
         F = Fm(t)-Fg(mi-mp(t), h)-Fd_drogue(h, V)-Fd(h, V); 
      else
         F = Fm(t)-Fg(mi-mp(t), h)-Fd(h, V); 
      end
      Fd_data = [Fd_data; Fd(h, V)];
      a = F/(mi-mp(t));
      A_data = [A_data; a];
      G_data = [G_data; a/9.81];
      V = V+a*ts;
      V_data = [V_data; V];
      h = h + V*ts;
      if h > 100 && V < 10
          drogue_deployed = 1;
      end
      if drogue_deployed && h < 300
          main_deployed = 1;
      end
      H = [H ; h];
      time = [time; t];
      t = t + ts;
  end
  
  % displaying data
  H = H*3.28084; %convert to ft
  plot(time, H);
  title('Velocity Diagram');
  xlabel('Time (s)');
  ylabel('Altitude (ft)');
  disp(['apogee: ', num2str(max(H)), ' ft']);
  disp(['time till apogee: ', num2str(find(H == max(H))*ts), ' s']);
  disp(['maximum velocity: ', num2str(max(V_data.*3.28084)), ' ft/s']);
  disp(['maximum G: ', num2str(max(G_data)), ' G']);