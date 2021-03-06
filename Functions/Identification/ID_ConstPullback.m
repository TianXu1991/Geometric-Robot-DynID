%% %% Inertial parameter identification with constant pullback distance regularization
% 2019 Taeyoon Lee

%% Inputs
% [Name]         [Description]                                                                     [Size]
%  Opt_type       'regularized' or 'point-to-set'                                                    
%  A              Regressor matrix                                                            N_sample*(N_body*10)
%  b              Observation vector                                                          N_sample*1
%  Phi_prior      Vectorized prior estimate of inertial parameters                                  10*N_body
%  Sigma          Observation variance                                                        N_sample*N_sample
%  gamma_or_c     (regularization factor) or (least square error bound)                               1
%  Q              Bounding ellipsoidal region => [x;1]'* Q * [x;1]' >=0                (cell: N_body) * (matrix: 4*4)

%% Outputs
% [Name]        [Description]                                                                        [Size]
%  Params        Identified inertial parameters                                                      struct
%   Params.Phi   Vectorized identified inertial parameters                                            10*N_body
%   Params.P     Pseudo inertia matrix representation of the identified inertial parameters          4*4*N_body
%  LS_error      Least square error on the training samples with the identified parameters              1

%% Implementation
function [ Params, LS_error ] = ID_ConstPullback( Opt_type, A, b, Phi_prior, Sigma, gamma_or_c, Q )
%% Initialization
if strcmp(Opt_type, 'regularized')
    fprintf(['Solving constant pullback distance ', Opt_type, ' identification formulation with regularization factor (gamma) = %f \n'], gamma_or_c); 
elseif strcmp(Opt_type, 'point-to-set')
    fprintf(['Solving constant pullback distance ', Opt_type, ' identification formulation with least square error bound (c) = %f \n'], gamma_or_c);
else
    display('Invalid optimization type. Choose regularized or point-to-set');
    Params = [];
    return
end

if ~exist('Q','var')
    display('E-density realizability condition is not used')
    bool_E_density_realizability = false;
else
    bool_E_density_realizability = true;
end

A           = Sigma^(-0.5) * A;
b           = Sigma^(-0.5) * b;
N_body      = size(Phi_prior,2);

Constant_pullback_metric_sqrt = zeros(10*N_body);  % Matrix square root of the constant pullback metric 
                                                   % (for ease of implementation using 'sum_square')
for i = 1 : N_body
    Constant_pullback_metric_sqrt(10*(i-1)+1:10*i,10*(i-1)+1:10*i) = pullback_metric(Phi_prior(:,i))^(0.5);
end

%% Identification
if strcmp(Opt_type, 'regularized')
    %% Regularized formulation
    
    gamma = gamma_or_c;
    cvx_begin
    
    variable Phi(10,N_body)                 % Vectorized inertial parameters Phi
    variable P(4,4,N_body) semidefinite     % 4 by 4 symmetric matrices of Pseudo inertia P 
    expression J_LS(1)                      % Least square error
    expression J_regularizer                % Regularizer
    
    
    J_LS = sum_square( A * Phi(:) - b );
    J_regularizer = sum_square( Constant_pullback_metric_sqrt * (Phi(:) -Phi_prior(:)) );
    
    minimize( J_LS + gamma * J_regularizer )
    
    subject to
    for i = 1 : N_body
        P(:,:,i) == inertiaVecToPinertia(Phi(:,i));
    end
    if bool_E_density_realizability
        for i = 1 : N_body
            trace( Q{i} * P(:,:,i) ) >= 0;
        end
    end
    
    cvx_end
    
elseif strcmp(Opt_type, 'point-to-set')
    %% Point-to-set formulation
    
    c = gamma_or_c;
    cvx_begin
    
    variable Phi(10,N_body)                 % Vectorized inertial parameters Phi
    variable P(4,4,N_body) semidefinite     % 4 by 4 symmetric matrices of Pseudo inertia P 
    expression J_LS(1)                      % Least square error
    expression J_regularizer                % Regularizer
    
    
    J_LS = sum_square( A * Phi(:) - b );
    J_regularizer = sum_square( Constant_pullback_metric_sqrt * (Phi(:) -Phi_prior(:)) );
    
    minimize( J_regularizer )
    
    subject to
    J_LS <= c;         %% Least square error bound constraint
    
    for i = 1 : N_body
        P(:,:,i) == inertiaVecToPinertia(Phi(:,i));
    end
    if bool_E_density_realizability
        for i = 1 : N_body
            trace( Q{i} * P(:,:,i) ) >= 0;
        end
    end
    
    cvx_end
    
end


%% Return identified parameters and least square error

Params.Phi = Phi;
Params.P   = P;

LS_error = J_LS;
end