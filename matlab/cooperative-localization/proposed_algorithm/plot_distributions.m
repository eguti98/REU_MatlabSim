function plot_distributions(COST,MEAN_ERROR,COVAR,PATH_DEVIATION,GOALS_REACHED,file_name)
%plot results distribution from all itteriations of an experiment
    figure()
    sgtitle(file_name);
    subplot(2,3,2)
    histogram(COST)
    title("COST")
    subplot(2,3,3)
    histogram(MEAN_ERROR)
    title("MEAN ERROR")
    subplot(2,3,4)
    histogram(COVAR)
    title("COVARIANCE NORM")
    subplot(2,3,5)
    histogram(PATH_DEVIATION)
    title("PATH DEVIATION")
    subplot(2,3,6)
    histogram(GOALS_REACHED)
    title("GOALS REACHED")
end