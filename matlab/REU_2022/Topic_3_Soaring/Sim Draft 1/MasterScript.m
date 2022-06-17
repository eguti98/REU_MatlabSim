
ParamMatrix = [...
    5, -5, 7;... LOW
    5, -5, 8;...
    5, -4, 7;...
    5, -4, 8;...
    6, -5, 7;...
    6, -5, 8;...
    6, -4, 7;...
    6, -4, 8;... MID
%     6, -4, 7;...
%     6, -3, 8;...
%     6, -3, 7;...
%     7, -4, 8;...
%     7, -4, 7;...
%     7, -3, 8;...
%     7, -3, 7 ... HIGH
    ];
render = false;
average = zeros(1,15);
surviving = zeros(1,15);
for i = 1:size(ParamMatrix,1)
    ParamS = 10^ParamMatrix(i,1);
    ParamC = 10^ParamMatrix(i,2);
    ParamA = 10^ParamMatrix(i,3);
    [average(i), surviving(i)] = MainScriptFunction(ParamS, ParamC, ParamA, i, render);
end
clf
load gong.mat;
% sound(y)
hold on

yyaxis left
plot(average);
yyaxis right
plot(surviving);
legend('Average Height','Number Surviving')