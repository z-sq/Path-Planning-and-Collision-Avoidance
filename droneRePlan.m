clc; clear; close all;
util = Utility();
waypoints = readmatrix('./pathMatrix.csv');
steps = 0;

% 3x3 matrix on the ground
ptClds(:,:,1) = [[0,0,0];[0,5,0];[0,10,0];[5,0,0];[5,5,0];[5,10,0];[10,0,0];[10,5,0];[10,10,0]];

ptClds(:,:,2) = [[0,0,25];[0,5,25];[0,10,25];[5,0,25];[5,5,25];[5,10,25];[10,0,25];[10,5,25];[10,10,25]]; 

% a line
ptClds(:,:,3) = [[25,25,25];[27.5,25,25];[30,25,25];[32.5,25,25];[35,25,25];[37.5,25,25];[40,25,25];[42.5,25,25];[45,25,25]];

% a cube with one FLS sticking out
ptClds(:,:,4) = [[45,15,15];[25,35,15];[45,35,15];[25,15,35];[25,35,35];[45,15,35];[45,35,35];[35,25,45];[25,15,15]];

% circle
ptClds(:,:,5) = [[25,40,25];[34.65,36.5,25];[39.75,27.6,25];[38,17.5,25];[30.15,10.9,25];[19.85,10.9,25];[12,17.5,25];[10.25,27.6,25];[15.35,36.5,25]];

% 3x3 matrix on the ground
ptClds(:,:,6) = [[0,0,0];[0,5,0];[0,10,0];[5,0,0];[5,5,0];[5,10,0];[10,0,0];[10,5,0];[10,10,0]];

startStep = 27561;
droneID = 1;
% change its position to 20 steps before's
waypoints(droneID + floor(startStep/9)*9,1:3) = [34.31783678,20.34115797,20.34108161];


stepToTarget = 0;
targetChange = 0;

target = waypoints(droneID + floor(startStep/9)*9,10);

apf = APF();

replanStep = inf;

potentialWayPts = [];

for j = 1:floor(startStep/9)
    waypointsPerStep = waypoints(j*9 - 8: j*9,:);

    for i = 1:9
        plot3(waypointsPerStep(i,1), waypointsPerStep(i,2), waypointsPerStep(i,3),'.','MarkerSize',10,'Color', [0 1 0]);
        hold on;
        steps = steps + 1;
        if steps > floor(startStep/9)*9
            break;
        end
        fprintf('%d step %d, drone %d at [%f, %f, %f], target %d\n', j, steps, i, waypointsPerStep(i,1:3),waypointsPerStep(i,10));
    end

end
pause(0.1);

for i = (droneID + floor(startStep/9)*9):9:size(waypoints,1)

    if waypoints(i,10) ~= target
        break;
    end

    stepToTarget = stepToTarget + 1;
end

while(replanStep > stepToTarget)
    % Calculate the maximun time spend
    targetPos = ptClds(1,:,mod(target,6));
    drone = Drone(droneID, waypoints(droneID + floor(startStep/9)*9,1:3), ptClds(1,:,mod(target,6)),waypoints(droneID + floor(startStep/9)*9,4:6),waypoints(droneID + floor(startStep/9)*9,7:9));
    drone.startPt = drone.position;

    replanStep = 0;
    potentialWayPts = [];

    while(1)            
        disp(replanStep);
        waypointsPerStep = waypoints((floor(startStep/9) + replanStep)*9 + 1:(floor(startStep/9) + replanStep)*9 + 9,:);
        

        checkPosition = waypointsPerStep(:,1:3);
        checkPosition(drone.ID,:) = [];

        for i = 1:8
            if norm(drone.position(:)-checkPosition(i,1:3)) <= 0.01
                plot3(colDronesPerTime(i).position(1),colDronesPerTime(i).position(2),colDronesPerTime(i).position(3),'r.','MarkerSize',30);
                disp('Collided');
                pause(0.1);
            end
        end
               
        drone = apf.getNextStep(drone,checkPosition);
    
        % re-write waypoints
        waypointsPerStep(drone.ID,:) = [drone.position, drone.velocity, drone.acceleration, target];
                  
        if norm(drone.position(:)-drone.target(:)) <= 0.01
            drone.arrived = true;
            disp("Re-planned and arrived!")
            fprintf("Origin Step %d, re-plan step %d, drone %d has arrived at target %d by replan\n", stepToTarget, replanStep, drone.ID, target);
            break;
        end
   
        potentialWayPts = [potentialWayPts;waypointsPerStep];

        replanStep = replanStep + 1;

    end
    target = target + 1;
end

waypoints((floor(startStep/9)*9 + 1):(floor(startStep/9) + replanStep)*9,:) = potentialWayPts;
for i = ((floor(startStep/9) + replanStep)*9 + droneID):9:(floor(startStep/9) - 1 + stepToTarget)*9
    waypoints(i,1:3) = waypoints((floor(startStep/9) + replanStep - 1)*9 + droneID,1:3);
end

for j = floor(startStep/9):size(waypoints,1)/9 - 1
    waypointsPerStep = waypoints(j*9 + 1: j*9 + 9,:);

    for i = 1:9
        if i == droneID && j < floor(startStep/9) + stepToTarget
            plot3(waypointsPerStep(i,1), waypointsPerStep(i,2), waypointsPerStep(i,3),'.','MarkerSize',10,'Color', [0 0 1]);
            hold on;
        else
            plot3(waypointsPerStep(i,1), waypointsPerStep(i,2), waypointsPerStep(i,3),'.','MarkerSize',10,'Color', [0 1 0]);
            hold on;
        end
        steps = steps + 1;

        fprintf('%d step %d, drone %d at [%f, %f, %f], target %d\n', j, steps, i, waypointsPerStep(i,1:3),waypointsPerStep(i,10));
    end

end
%   Replan this drone's path

