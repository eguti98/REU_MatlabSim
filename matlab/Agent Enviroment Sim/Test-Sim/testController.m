function testController(agent)
if ~isempty(agent.measuredAgents)
   for i = 1:length(agent.measuredAgents)
       distance =.01*(agent.pose - agent.measuredAgents(i).pose);
       agent.velocityControl = agent.maxSpeed*distance/norm(distance); 
   end
else
    agent.velocityControl = agent.maxSpeed*[sqrt(2)/2, sqrt(2)/2];
end
   idealUnit = agent.calcIdealUnitVec;
   colorVec = [.5*idealUnit+.5,.5];
   agent.color = colorVec;
   
end

