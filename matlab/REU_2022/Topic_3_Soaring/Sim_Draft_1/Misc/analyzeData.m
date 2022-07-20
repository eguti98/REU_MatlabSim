%% Prepare workspace
close all
clear
clc
addpath("../Output_Media/BigBatch");

%% Load in data
fileFolder = "../Output_Media/BigBatch/7-19-22/";
excelFiles = ["SimData_20220719130449.xlsx","SimData_20220719130452.xlsx"];
sheetNum = 1;
startingColumn = 3;

inputData = cell(0,0);
outputData = cell(0,0);
for fileIndex = 1:length(excelFiles)
    excelFileName = fileFolder + excelFiles(fileIndex);
    RAW = readcell(excelFileName,'Sheet',sheetNum);
    outputRow = -1;
    for i=1:size(RAW,1)
        if(RAW{i,1} == "OUTPUT")
            outputRow = i;
        end
    end
    fprintf("OutputRow: %d\n",outputRow);
    numChangedVariables = 0;
    while(~ismissing(RAW{outputRow+1+numChangedVariables,2}))
        numChangedVariables = numChangedVariables + 1;
    end
    fprintf("NumChangedVariables: %d\n",numChangedVariables);
    numOutputVariables = size(RAW,1)-(outputRow+numChangedVariables+2)+1;
    fprintf("NumOutputVariables: %d\n",numOutputVariables);
    numSims = size(RAW,2)-startingColumn+1;
    
    rowChangedVar = outputRow + 1;
    rowOutputVar = rowChangedVar + numChangedVariables + 1;
    
    tempInputData = cell(numSims,numChangedVariables);
    tempOutputData = cell(numSims,numOutputVariables);
    
    for sim=1:numSims
        for i=1:numChangedVariables
            tempInputData{sim,i} = RAW{rowChangedVar+i-1,startingColumn+sim-1};
        end
        for i=1:numOutputVariables
            tempOutputData{sim,i} = RAW{rowOutputVar+i-1,startingColumn+sim-1};
        end
    end
    
    inputData = [inputData;tempInputData];
    outputData = [outputData;tempOutputData];
    
    if(fileIndex == length(excelFiles))
        for i=1:numChangedVariables
            idata.(RAW{rowChangedVar+i-1,startingColumn-1}) = [inputData{:,i}];
        end

        for i=1:numOutputVariables
            odata.(RAW{rowOutputVar+i-1,startingColumn-1}) = [outputData{:,i}];
        end
    end
end

%{
Small:

scatter3(idata.cohesion,idata.separation,odata.surviving);
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Cohesion');
ylabel('Separation');
zlabel('Surviving');


Big:
clf;
tiledlayout(2,2);
nexttile;
scatter3(idata.cohesion,idata.separation,odata.surviving);
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Cohesion');
ylabel('Separation');
zlabel('Surviving');
nexttile;
scatter3(idata.cohesion,idata.separation,odata.heightScore);
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Cohesion');
ylabel('Separation');
zlabel('Height Score');
nexttile;
scatter3(idata.cohesion,idata.separation,odata.explorationPercent);
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Cohesion');
ylabel('Separation');
zlabel('Exploration Percent');
nexttile;
scatter3(idata.cohesion,idata.separation,odata.thermalUseScore);
set(gca,'XScale','log');
set(gca,'YScale','log');
xlabel('Cohesion');
ylabel('Separation');
zlabel('Thermal Use Score');


Feature Selection:
X = [idata.rngSeed',idata.cohesion',idata.cohesionAscensionIgnore',idata.separation',idata.alignment'];
Y = odata.surviving;
[idx,scores] = fscchi2(X,Y);
if(isempty(find(isinf(scores))))
    bar(idx,scores(idx))
    xlabel('Predictor rank')
    ylabel('Predictor importance score')
else
    fprintf("Inf values!\n");
end
%}
