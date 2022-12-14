clc; clear; close all;
util = Utility();
% startPtFile = "Point Cloud Squence/pt1379_change.ptcld";
% targetPtFiles = ["pt1547_change.ptcld", ""];

% Configurable parameters
stoptime = 1;
removeWhenCollide = true;
iterations = 1;
timeunit = 1/25;

ptClds = [];
direction = [];
distLeft = [];
waypoints = [];
collisionPt = [];
arriveNum = 0;
color = [[0,0,0];[0.7,0,0];[0,0,1];[1,0,1];[0,1,0];[0,1,1];[1,1,1];[1,1,0]];
collisions = [];
collisionsAgain = [];
collisionAgainDrones = [];
displayCell = [];
illuminationCell = [];
sizeOfIllumCell = 5;
dispCellSize = 0.1;
speedLimit = 1;

totalSteps = 0;
ans = [];

centralPoint = [0,0,0];
travalRadius = 150;
for angle = 1: 1: 179
    radian = angle * pi/180;
    initialPts = [[centralPoint(1) - travalRadius,centralPoint(2),centralPoint(3)];...
        [centralPoint(1) - cos(radian) * travalRadius,centralPoint(2) - sin(radian) * travalRadius,centralPoint(3)]];
    
    ptCld = [[centralPoint(1) + travalRadius,centralPoint(2),centralPoint(3)];...
        [centralPoint(1) + cos(radian) * travalRadius,centralPoint(2) + sin(radian) * travalRadius,centralPoint(3)]];
    
    
    step = 0;
    replanStep = 0;
    arriveNum = 0;
    nearByDrones = [];
    colDrones = [];
    colDronesPerTime = [];
    potentialCollide = false;
    
    for i = 1:size(initialPts,1)
        drones(i) = Drone(i,initialPts(i,:),[0,0,0],[0,0,0],[0,0,0]);
        waypointsPerStep = [drones(i).position, drones(i).velocity, drones(i).acceleration,1];
    end
    
    
    dronesNum = length(drones);
    
    targetSequence = 0;

        for i = 1:length(drones)
            drones(i).startPt = drones(i).position;
            drones(i).target = ptCld(i,:);
            drones(i).arrived = false;
            drones(i).velocity = [0,0,0];
            drones(i).distTraveled = 0;
        end

        % set the moving direction of each drones
        for i = 1:size(ptCld)
            direction(i,:) = util.differential(drones(i).position, ptCld(i,:));
            distLeft(i) = norm(drones(i).position - ptCld(i,:));
        end
        
        while arriveNum ~= dronesNum 
            step = step + 1;
            disp(step);
            for i = 1:length(drones)
                accTime = 0;
                
                %   if the drone has arrived, skip
                if drones(i).arrived
                    continue
                end
                
%                 %   if the drone has already been removed, ignore it
%                 if drones(i).removed
%                     continue
%                 end

                % if the drone is already arrived, or just arrived, skip
                if all(abs(drones(i).position - drones(i).target)<=[0.002,0.002,0.002])
                    drones(i).arrived = true;
                    arriveNum = arriveNum + 1;
                    drones(i).velocity = [0,0,0];
                    fprintf("Drone %d arrived, %d has arrived and %d left\n", i, arriveNum, dronesNum-arriveNum);
                    %disp(step); 
                    continue
                end
                

                % Check if the drone needs to speed up or slow down
                v = norm(drones(i).velocity);
                tToSlow = v /(speedLimit * drones(i).accMax);
                distToSlow = 0.5 * v * tToSlow;
                

                %   If the distance left is no bigger than the minimum
                %   slowing down distance
                if distLeft(i) > distToSlow && ((distLeft(i) - (v * timeunit + 0.5 * speedLimit * drones(i).accMax * timeunit^2)) < (distToSlow + (timeunit * v + 0.5 * (speedLimit * drones(i).accMax)^2 * timeunit^2)))
  
                    %accTime = (sqrt(4* v^2 + 4 * drones(i).accMax * (distLeft(i) - distToSlow)) - 2 * v)/ (2 * drones(i).accMax);
                    accValue = (-(v*timeunit/(speedLimit * drones(i).accMax) + 0.5*timeunit^2)+sqrt((v*timeunit/(speedLimit * drones(i).accMax) + 0.5*timeunit^2)^2 + 2*(timeunit^2/(speedLimit * drones(i).accMax))*(distLeft(i) - v*timeunit - (v^2)/(2* speedLimit * drones(i).accMax))))...
                        /(timeunit^2/(speedLimit * drones(i).accMax));
                    %maxSpeed = v +  accTime * drones(i).accMax;
                    %maxt = maxSpeed/(drones(i).accMax);

                    %newV = drones(i).velocity + drones(i).accMax * accTime * direction(i,:) - drones(i).accMax * (timeunit-accTime) * direction(i,:);
                    %positionMoved = drones(i).velocity * accTime + 0.5 * drones(i).accMax * accTime^2 * direction(i,:) + newV * (timeunit-accTime) ...
                     %   + 0.5 * drones(i).accMax * (timeunit-accTime)^2 * direction(i,:);

                    newV = drones(i).velocity + accValue * timeunit * direction(i,:);
                    positionMoved = drones(i).velocity * timeunit + 0.5 * accValue * timeunit^2 * direction(i,:);

                    newdistToSlow = (0.5 * (v+accValue*timeunit)^2) /(speedLimit * drones(i).accMax);
                    left = distLeft(i) - norm(positionMoved);%(0.5 *accValue*timeunit^2 + v * timeunit);
                    
                elseif distLeft(i) <= distToSlow
                    accValue = min(v/timeunit, speedLimit * drones(i).accMax);
                    newV = drones(i).velocity - accValue * timeunit * direction(i,:);
                    positionMoved = 0.5 * (drones(i).velocity + newV) * timeunit;

                    newdistToSlow = (0.5 * (v-accValue*timeunit)^2) /(speedLimit * drones(i).accMax);

                elseif  v == speedLimit * drones(i).vMax
                    accValue = 0;
                    newV = drones(i).velocity;
                    positionMoved = newV * timeunit;

                    newdistToSlow = distToSlow;
                else
                    %accTime = min((drones(i).vMax - v)/drones(i).accMax, timeunit); 
                    accValue = min((speedLimit * drones(i).vMax - v)/timeunit, speedLimit * drones(i).accMax);
                    newV = drones(i).velocity + accValue * timeunit * direction(i,:);
                    positionMoved = 0.5 * accValue * direction(i,:) * timeunit^2 + drones(i).velocity * timeunit;

                    newdistToSlow = (0.5 * (v+accValue*timeunit)^2) /(speedLimit * drones(i).accMax);
                end

                distMoved = norm(positionMoved);
                distLeft(i) = distLeft(i) - distMoved;

                drones(i).acceleration = accValue * direction(i,:);

                drones(i).position = drones(i).position + positionMoved;
                drones(i).velocity = newV;
                drones(i).distTraveled = drones(i).distTraveled + distMoved;
                

                %fprintf("Moving %.4f at step %d with speed %.2f\n", distMoved, step, norm(newV));
                waypointsPerStep(i,:) = [drones(i).position, drones(i).velocity, drones(i).acceleration,targetSequence];

%                 v = norm(drones(i).velocity);
%                 tToSlow = v /(drones(i).accMax);
%                 distToSlow = 0.5 * v * tToSlow;
%                 fprintf("the %d th drone is at (%f,%f,%f), with the speed %f, dist left %f, dist to slow %f\n", i, drones(i).position, norm(drones(i).velocity), distLeft(i), newdistToSlow);
                
%                 plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',10,'Color', color(mod(k,4) + 4,:));
%                 hold on;
%                 fprintf("the %d th drone is at (%f,%f,%f), with the speed %f, dist left %f, dist to slow %f\n", i, drones(i).position, norm(drones(i).velocity), distLeft(i), newdistToSlow);
                
%                 plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',10,'Color', color(mod(k,4) + 4,:));
%                 hold on;
            end
            
%             % collision detection
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
                        hold on;
                        fprintf("Drone %d and %d collided at [%.2f,%.2f,%.2f], step = %d\n",i,m,drones(i).position,step);
                        %dronesNum = dronesNum - 1;
                        %pause(2);
                        potentialCollide = true;
                        colDronesPerTime = [colDronesPerTime, drones(m)];
                        %nearByDrones = [nearByDrones, drones(m)];
                        

                        %find drones in neighbor illumination cells
                        illumCellDIn = [];
                        illumCellDIn(1) = floor((drones(i).position(1)/dispCellSize)/sizeOfIllumCell); 
                        illumCellDIn(2) = floor((drones(i).position(2)/dispCellSize)/sizeOfIllumCell); 
                        illumCellDIn(3) = floor((drones(i).position(3)/dispCellSize)/sizeOfIllumCell); 

                        for y = 1:length(drones)
                            if y == m || y == i
                                continue
                            end
                            isNeighbor = true;
                            for z = 1:3
                                isNeighbor = all(isNeighbor) && all(drones(y).position(z) > dispCellSize * (illumCellDIn(z) - sizeOfIllumCell/2));
                                isNeighbor = all(isNeighbor) && all(drones(y).position(z) < dispCellSize * (illumCellDIn(z) - sizeOfIllumCell/2));
                            end
                            if isNeighbor
                                nearByDrones = [nearByDrones, drones(y)];
                            end
                        end

                    end
                end
% 
                if collisionDNum > 0
                    collisionDNum = collisionDNum + 1;
                    %colDronesPerTime = [colDronesPerTime, drones(i)];
                    nearByDrones = [nearByDrones, drones(i)];
                    drones(i).removed = true;
                    %dronesNum = dronesNum -1;
                    collisions = [collisions,collisionDNum];
                end
            end

%             if ~removeWhenCollide
%                 for i = 1:length(drones)
%                     drones(i).removed = false;
%                 end
%                 potentialCollide = false;
%             end

            waypoints = [waypoints; waypointsPerStep];
            originWaypoints = waypoints;
            originStep = step;
        end
        if angle == 1
            plot3(waypoints(:,1), waypoints(:,2), waypoints(:,3),'.','MarkerSize',10,'Color', color(5,:));
            hold on;
        end

        % When a collision happens, we record the collision co-ordinate, the ID of
        % collision drons. Re-plan the path for the colliding drones, starting
        % form the last point cloud formation 
        if 1%potentialCollide
            step = originStep;
            waypoints = originWaypoints;
            arrivedDrones = 0;
            collisionAgainDrones = [];
            colDronesPerTime = [drones(2)];
            nearByDrones = [drones(1)];
   
        
            checkPosition = [];
            for x = 1:length(colDronesPerTime)
                colDronesPerTime(x).position = colDronesPerTime(x).startPt;
                colDronesPerTime(x).arrived = false;
                colDronesPerTime(x).removed = false;
                colDronesPerTime(x).distTraveled = 0;
                colDronesPerTime(x).velocity = 0;
            end
            
            apf = APF();
            while length(colDronesPerTime) ~= arrivedDrones
                replanStep = replanStep + 1;
                if replanStep == 5
                    pause(0.1);
                end
                disp(replanStep);
                if replanStep <= step
                    waypointsPerStep = waypoints(end-(step - replanStep + 1)*dronesNum + 1:end - (step - replanStep) * dronesNum,:);
                end

                for i = 1:length(colDronesPerTime)

                    checkPosition = [];
                    if colDronesPerTime(i).arrived
                        continue;
                    end
                    
                    for x = 1:i-1
                        checkPosition = [checkPosition;colDronesPerTime(x).position];
                    end

                    for x = 1:length(nearByDrones)
                        laststep = min(replanStep, step);
                        checkPosition = [checkPosition;waypoints(nearByDrones(x).ID + dronesNum * (laststep - 1),1:3)];
                    end
                    colDronesPerTime(i) = apf.getNextStep(colDronesPerTime(i),checkPosition);

                    % re-write waypoints
                    waypointsPerStep(colDronesPerTime(i).ID,:) = [colDronesPerTime(i).position, colDronesPerTime(i).velocity, colDronesPerTime(i).acceleration, targetSequence];

                              
                    if norm(colDronesPerTime(i).position(:)-colDronesPerTime(i).target(:)) <= 0.015
                        colDronesPerTime(i).arrived = true;
                        arrivedDrones = arrivedDrones + 1;
                        fprintf("Origin Step %d, re-plan step %d, drone %d has arrived by replan, moving %.2f while origin %.2f\n", step, replanStep, colDronesPerTime(i).ID, colDronesPerTime(i).distTraveled, norm(colDronesPerTime(i).target-colDronesPerTime(i).startPt));
                        ans = [angle, step, replanStep];
                        util.saveCSV(ans, './angleEffect.csv');
                        %dronesNum = dronesNum + 1;
                    end
                    %disp(steps);
                end
                % to those collide again, maintain there last position
                % before colliding
                for x = 1:length(collisionAgainDrones)
                    collisionAgainDrones(x).position = waypoints(x + dronesNum * (replanStep - 2),1:3);
                    waypointsPerStep(collisionAgainDrones(x).ID,:) = waypoints(x + dronesNum * (replanStep - 2),:);
                end
                
                waypoints(1 + dronesNum * (replanStep - 1):dronesNum * replanStep,:) = waypointsPerStep;

                 % collision detection
                for i = 1:length(colDronesPerTime)
                    colAgainDNum = 0;
                    collisionAgainDrones = [];
    
                    if colDronesPerTime(i).removed
                        continue
                    end
    
                    for m = 1:length(drones)
                        if norm(colDronesPerTime(i).position - waypoints(drones(m).ID + dronesNum * (replanStep - 1),1:3))<= 0.1 && colDronesPerTime(i).ID ~= m 
                            colAgainDNum = colAgainDNum + 1;
                            drones(m).removed = true;
                            plot3(colDronesPerTime(i).position(1),colDronesPerTime(i).position(2),colDronesPerTime(i).position(3),'r.','MarkerSize',30);
                            hold on;
                            fprintf("Drone %d and %d collided again at [%f,%f,%f] with distance %f ", ...
                                colDronesPerTime(i).ID, m, waypoints(drones(m).ID + dronesNum * (replanStep - 1),1:3),norm(colDronesPerTime(i).position - waypoints(drones(m).ID + dronesNum * (replanStep - 1),1:3)))

                            if m <= length(colDronesPerTime)
                                arrivedDrones = arrivedDrones + 1;
                            end
                            pause(2);

                            if removeWhenCollide
                               collisionAgainDrones = [collisionAgainDrones, drones(m)];
                            end

                            potentialCollide = true;
                        end
                    end
    
                    if colAgainDNum > 0
                        colAgainDNum = colAgainDNum + 1;
                        colDronesPerTime(i).removed = true;
                        %dronesNum = dronesNum -1;
                        collisionsAgain = [collisionsAgain,colAgainDNum];
                        collisionAgainDrones = [collisionAgainDrones, colDronesPerTime(i)];
                        arrivedDrones = arrivedDrones + 1;
                    end
                end
%                 plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',10,'Color', [0 0 1]);
%                 hold on;
    
                if ~removeWhenCollide
                    for i = 1:length(nearByDrones)
                        nearByDrones(i).removed = false;
                    end
                    
                    for i = 1:length(colDronesPerTime)
                        colDronesPerTime(i).removed = false;
                    end
                    potentialCollide = false;
                end
                
            end


        end

        potentialCollide = false;

        %   mark the target point
        %plot3(waypointsPerStep(:,1), waypointsPerStep(:,2), waypointsPerStep(:,3),'.','MarkerSize',20,'Color', color(j,:));
        %hold on;

        for i = 1:length(colDronesPerTime)
            drones(colDronesPerTime(i).ID) = colDronesPerTime(i);
        end

        for i = 1: (stoptime/0.04)
            step = step + 1;
            waypoints = [waypoints; waypointsPerStep];
        end
        
        %disp(waypoints);
        %util.saveCSV(waypoints);
        totalSteps = totalSteps + size(waypoints,1) / dronesNum;

        fprintf('current point cloud takes %d steps, total %d steps\n', size(waypoints,1) / dronesNum, totalSteps);
        pause(0.1);

end
disp(totalSteps);
figure(2);
h = histogram(collisions, length(dronesNum));
xlabel('FLSs involved in the Collision','FontSize',16);
ylabel('Collision Times','FontSize',16);

figure(3);
h = histogram(collisionsAgain, length(dronesNum));
xlabel('FLSs involved in the Collision','FontSize',16);
ylabel('Collision Again Times','FontSize',16);


