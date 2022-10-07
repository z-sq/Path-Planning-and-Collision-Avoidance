clc; clear; close all;
util = Utility();
% startPtFile = "Point Cloud Squence/pt1379_change.ptcld";
% targetPtFiles = ["pt1547_change.ptcld", ""];

% Configurable parameters
stoptime = 1;
removeWhenCollide = true;
iterations = 2;
ptCldNums = 4;
timeunit = 1/100;
ptCldSeq = [1,2,3,4];

ptClds = [];
direction = [];
distLeft = [];
waypoints = [];
collisionPt = [];
arriveNum = 0;
color = [[0,0,0];[0.7,0,0];[0,0,1];[1,0,1];[0,1,0];[0,1,1];[1,1,1];[1,1,0]];
collisions = [];


% initialPts = util.loadPtCld(startPtFile);
% 
% for i = 1:size(targetPtFiles)
%     targets(i) = util.loadPtCld("Point Cloud Squence/" + targetPtFiles(i));
% end

% 3x3 matrix on the ground
initialPts = [[0,0,0];[0,1,0];[0,2,0];[1,0,0];[1,1,0];[1,2,0];[2,0,0];[2,1,0];[2,2,0]];

% lifting up to the 3x3 matrix in the air
ptClds(:,:,1) = [[0,0,5];[0,1,5];[0,2,5];[1,0,5];[1,1,5];[1,2,5];[2,0,5];[2,1,5];[2,2,5]]; 

% a line
ptClds(:,:,2) = [[5,5,5];[5.5,5,5];[6,5,5];[6.5,5,5];[7,5,5];[7.5,5,5];[8,5,5];[8.5,5,5];[9,5,5]];

% a cube with one FLS sticking out
ptClds(:,:,3) = [[9,3,3];[5,7,3];[9,7,3];[5,3,7];[5,7,7];[9,3,7];[9,7,7];[7,5,9];[5,3,3]];

% circle
ptClds(:,:,4) = [[5,8,5];[6.93,7.3,5];[7.95,5.52,5];[7.6,3.5,5];[6.03,2.18,5];[3.97,2.18,5];[2.4,3.5,5];[2.05,5.52,5];[3.07,7.3,5]];


for i = 1:length(initialPts)
    drones(i) = Drone(i,initialPts(i,:),[0,0,0],[0,0,0],[0,0,0]);
end

waypointsPerStep = initialPts;

dronesNum = length(drones);

for k = 1:iterations


    startPtCld = 2;
    endPtCld = ptCldNums;
    % the first iteration needs to have lifting process
    if k == 1
        startPtCld = 1;
    end

    % the last iteration needs to have landing process
    if k == iterations
        endPtCld = ptCldNums + 2;
    end


    for j = startPtCld:endPtCld 
        if j == ptCldNums + 1
            ptCld = ptClds(:,:,1);
        elseif j == ptCldNums + 2
            ptCld = initialPts;
        else
            ptCld = ptClds(:,:,ptCldSeq(j));
        end
        

        step = 0;
        arriveNum = 0;
        nearByDrones = [];
        colDrones = [];
        colDronesPerTime = [];
        potentialCollide = false;

        for i = 1:length(drones)
            drones(i).startPt = drones(i).position;
            drones(i).target = ptCld(i,:);
            drones(i).arrived = false;
        end

        % set the moving direction of each drones
        for i = 1:size(ptCld)
            direction(i,:) = util.differential(drones(i).position, ptCld(i,:));
            distLeft(i) = norm(drones(i).position - ptCld(i,:));
        end
        
        while arriveNum ~= dronesNum
            step = step + 1;
            
            for i = 1:length(drones)
                accTime = 0;
                
                %   if the drone has arrived, skip
                if drones(i).arrived
                    continue
                end
                
                %   if the drone has already been removed, ignore it
                if drones(i).removed
                    continue
                end

                % if the drone is already arrived, or just arrived, skip
                if all(abs(drones(i).position - drones(i).target)<=[0.0001,0.0001,0.0001])
                    drones(i).arrived = true;
                    arriveNum = arriveNum + 1;
                    drones(i).velocity = [0,0,0];
                    fprintf("Drone %d arrived, at speed (%f,%f,%f)\n", i, drones(i).velocity)
                    continue
                end
                

                % Check if the drone needs to speed up or slow down
                v = norm(drones(i).velocity);
                tToSlow = v /(drones(i).accMax);
                distToSlow = 0.5 * v * tToSlow;
                

                %   If the distance left is no bigger than the minimum
                %   slowing down distance
                if distLeft(i) > distToSlow && ((distLeft(i) - (v * timeunit + 0.5 * drones(i).accMax * timeunit^2)) < (distToSlow + (timeunit * v + 0.5 * drones(i).accMax^2 * timeunit^2)))
  
                    accTime = (sqrt(4* v^2 + 4 * drones(i).accMax * (distLeft(i) - distToSlow)) - 2 * v)/ (2 * drones(i).accMax);

                    maxSpeed = v +  accTime * drones(i).accMax;
                    maxt = maxSpeed/(drones(i).accMax);
                    newdistToSlow = 0.5 * maxSpeed* maxt;
                    left = distLeft(i) - 0.5 * (v+maxSpeed) * accTime;

                    newV = drones(i).velocity + drones(i).accMax * accTime * direction(i,:) - drones(i).accMax * (timeunit-accTime) * direction(i,:);
                    positionMoved = drones(i).velocity * accTime + 0.5 * drones(i).accMax * accTime^2 * direction(i,:) + newV * (timeunit-accTime) ...
                        + 0.5 * drones(i).accMax * (timeunit-accTime)^2 * direction(i,:);
                    
                elseif distLeft(i) <= distToSlow
                    accTime = min(v/drones(i).accMax,timeunit);
                    newV = drones(i).velocity - drones(i).accMax * accTime * direction(i,:);
                    positionMoved = 0.5 * (drones(i).velocity + newV) * accTime;

                elseif  v == drones(i).vMax
                    accTime = 0;
                    newV = drones(i).velocity;
                    positionMoved = newV * timeunit;
                else
                    accTime = min((drones(i).vMax - v)/drones(i).accMax, timeunit); 
                    newV = drones(i).velocity + drones(i).accMax * accTime * direction(i,:);
                    positionMoved = 0.5 * (drones(i).velocity + newV) * accTime + newV * (timeunit-accTime);
                end

                distMoved = norm(positionMoved);

                distLeft(i) = distLeft(i) - distMoved;

                drones(i).position = drones(i).position + positionMoved;
                drones(i).velocity = newV;
                
                waypointsPerStep(i,:) = drones(i).position;

%                 v = norm(drones(i).velocity);
%                 tToSlow = v /(drones(i).accMax);
%                 distToSlow = 0.5 * v * tToSlow;

                %fprintf("the %d th drone is at (%f,%f,%f), with the speed %f, dist left %f, dist to slow %f\n", i, drones(i).position, norm(drones(i).velocity), distLeft(i), distToSlow);
                
                plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',10,'Color', color(mod(k,4) + 4,:));
                hold on;
            end
            
            % collision detection
            for i = 1:length(drones)
                collisionDNum = 0;
                if drones(i).removed
                    continue
                end

                for m = (i + 1):length(drones)
                    if norm(drones(i).position - drones(m).position)<= 0.1 && ~drones(m).removed
                        collisionDNum = collisionDNum + 1;

                        %   marke all colliding drones
                        drones(m).removed = true;
                        plot3(drones(i).position(1),drones(i).position(2),drones(i).position(3),'r.','MarkerSize',30);
                        disp("Collided!")
                        dronesNum = dronesNum - 1;
                        %pause(2);
                        potentialCollide = true;
                        colDronesPerTime = [colDronesPerTime, drones(m)];
                    end
                end

                if collisionDNum > 0
                    collisionDNum = collisionDNum + 1;
                    colDronesPerTime = [colDronesPerTime, drones(i)];
                    drones(i).removed = true;
                    dronesNum = dronesNum -1;
                    collisions = [collisions,collisionDNum];
                end
            end

            if ~removeWhenCollide
                for i = 1:length(drones)
                    drones(i).removed = false;
                end
                potentialCollide = false;
            end

            waypoints(:,:,step) = [waypointsPerStep];
        end

        % When a collision happens, we record the collision co-ordinate, the ID of
        % collision drons. Re-plan the path for the colliding drones, starting
        % form the last point cloud formation 
        if potentialCollide

            replanStep = 0;
            arrivedDrones = 0;
            collisionAgainDrones = [];

            % get near by drones

            nearByDrones = [];
            
            checkPosition = [];
            
            apf = APF();
            while length(colDronesPerTime) ~= arrivedDrones
                replanStep = replanStep + 1;
                for i = 1:length(colDronesPerTime)
                    if colDronesPerTime(i).arrived
                        continue;
                    end
                    
                    for x = 1:length(colDronesPerTime)
                        checkPosition = [checkPosition;waypoints(colDronesPerTime(x).ID,:,replanStep)];
                    end

                    for x = 1:length(nearByDrones)
                        checkPosition = [checkPosition;waypoints(nearByDrones(x).ID,:,replanStep)];
                    end

                    [colDronesPerTime(i).position, colDronesPerTime(i).velocity] = apf.getNextStep(colDronesPerTime(i),checkPosition);

                    % re-write waypoints
                    waypointsPerStep = waypoints(:,:,replanStep);
                    waypointsPerStep(colDronesPerTime(i).ID,:) = colDronesPerTime(i).position;
                    for x = 1:size(collisionAgainDrones)
                        waypointsPerStep(collisionAgainDrones(x),:) = waypoints(x,:,replanStep - 1);
                    end
                    
                    waypoints(:,:,replanStep) = waypointsPerStep;
            
                    if ~all(abs(colDronesPerTime(i).position(:)-colDronesPerTime(i).target(:))<=[0.00001,0.00001,0.00001])
                        colDronesPerTime(i).arrived = true;
                        arrivedDrones = arrivedDrones + 1;
                        disp("Re-planned and arrived!")
                    end
                    %disp(steps);
                end

                 % collision detection
                for i = 1:length(colDronesPerTime)
                    colAgainDNum = 0;
    
                    if colDronesPerTime(i).removed
                        continue
                    end
    
                    for m = 1:length(nearByDrones)
                        if norm(colDronesPerTime(i).position - waypoints(nearByDrones(m).ID,:,replanStep))<= 0.1 && ~nearByDrones(m).removed
                            colAgainDNum = colAgainDNum + 1;
                            nearByDrones(m).removed = true;
                            plot3(colDronesPerTime(i).position(1),colDronesPerTime(i).position(2),colDronesPerTime(i).position(3),'r.','MarkerSize',30);
                            disp("Collided Again!")
                            if m <= length(colDronesPerTime)
                                arrivedDrones = arrivedDrones + 1;
                            end
                            %pause(2);

                            if removeWhenCollide
                               collisionAgainDrones = [collisionAgainDrones, nearByDrones(m)];
                            end

                            potentialCollide = true;
                        end
                    end
    
                    if colAgainDNum > 0
                        colAgainDNum = colAgainDNum + 1;
                        colDronesPerTime(i).removed = true;
                        dronesNum = dronesNum -1;
                        collisionsAgain = [collisionsAgain,colAgainDNum];
                        collisionAgainDrones = [collisionAgainDrones, colDronesPerTime(i)];
                        arrivedDrones = arrivedDrones + 1;
                    end
                end

                plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',10,'Color', color(mod(k,4) + 4,:));
                hold on;
    
                if ~removeWhenCollide
                    for i = 1:length(nearByDrones)
                        nearByDrones(i).removed = false;
                    end
                    
                    for i = 1:length(colDronesPerTime)
                        colDronesPerTime(i).removed = false;
                    end
                    potentialCollide = false;
                end
                
                replanStep = replanStep + 1;
            end

        end

        potentialCollide = false;

        %   mark the target point
        plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',20,'Color', color(j,:));
        hold on;

        for i = 1: (stoptime/timeunit)
            step = step + 1;
            waypoints(:,:,step) = [waypointsPerStep];
        end

        %util.saveCSV(waypoints);

        pause(0.1)
    end
end

figure(2);
h = histogram(collisions, length(initialPts));
xlabel('FLSs involved in the Collision','FontSize',16);
ylabel('Collision Times','FontSize',16);



