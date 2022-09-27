classdef APF
    %APF Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        
        obstacles;

        %   Corrdinates
        target;
        startPt;
        path;
    
        %   Feild data sets
        timeUnit = 1/25;
        stepsize = 0.2;
        attBound = 5;
        repDist = 3;
        threshold = 0.2;

        %   Coefficients
        epsilon = 0.5;
        etaR = 0.2;
        etaV = 0.2;
        
        fAttMax;
        
        util;
        
    end
    
    methods

        function self = APF(obstacles,startPt,target)
            self.obstacles = obstacles;
            self.target = target;
            self.startPt= startPt;
            self.path = startPt;
       
            self.util = Utility();
            self.fAttMax = self.util.distanceCost([0,0,0],self.attraction(startPt,target,self.attBound,self.epsilon));
        end


        % Compute the attractive force
        function f_att = attraction(self,dronePos,target,distBound,epsilon)
            dis = self.util.distanceCost(dronePos,target);
        
            %   To prevent attraction force grown too big when it's far from target
            %   Set an upper bound to the arraction force
            if dis <= distBound
                fx = epsilon * (target(1) - dronePos(1));
                fy = epsilon * (target(2) - dronePos(2));
                fz = epsilon * (target(3) - dronePos(3));
            else
                fx = distBound * epsilon * (target(1) - dronePos(1)) / dis;
                fy = distBound * epsilon * (target(2) - dronePos(2)) / dis;
                fz = distBound * epsilon * (target(3) - dronePos(3)) / dis;
            end
        
            %   Return a the attraction force vector
            f_att = [fx, fy, fz];
        end


        %   Calculate the total Velocity-Repulsive force
        function f_VRep = repulsion(self,drone,obstacles,affectDistance,etaR, etaV,target)
            f_VRep = [0, 0, 0];           %Initialize the force
            distToTarget = self.util.distanceCost(drone.position,target);
            n=2;    %n is an arbitrary real number which is greater than zero
        
            for i = 1 : size(obstacles,2)
                % skip the drone itself
                if isequal(drone.position,obstacles(i).position) 
                    continue;
                end

                distToObst = self.util.distanceCost(drone.position,obstacles(i).position);
                
                %Drone is affecting by abstacle's repulsivefield
                if distToObst <= affectDistance && self.util.distanceCost(drone.velocity, obstacles(i).velocity) > 0
                    %   Calculate the repulsive force
                    fRepByObst = etaR * (1/distToObst - 1/affectDistance) * distToTarget^n/distToObst^2 * self.util.differential(drone.position,obstacles(i).position)...
                        + (n/2) * etaR * (1/distToObst - 1/affectDistance)^2 * distToTarget^(n-1) * self.util.differential(drone.position,target);
                    
                    %   Calculate the velocity repulsive force
                    fVByObst = etaV * self.util.distanceCost(obstacles(i).velocity, drone.velocity) * self.util.differential(drone.position,obstacles(i).position);
                    
                    f_VRep = f_VRep + fRepByObst + fVByObst;
                    fprintf('affect by %f, with rep of %f and Vrep of %f\n',obstacles(i).position, fRepByObst,fVByObst);
                end
                fprintf('total force %f\n', f_VRep);
            end
        end
       

        %Calculate the next step for current drone
        %   Consider add up kinematicConstrant later
        function [nextPos,changedV] = getNextStep(self,drone)
            force = self.getTotalForce(drone);
            %nextPos = drone.position + 0.2 * force;
            %changedV = 0.2/drone.timeUnit * force;

            %nextPos = drone.position + drone.velocity * self.timeUnit + 0.5 * drone.accMax * force * self.timeUnit^2;
            %changedV = drone.velocity + drone.accMax * force * self.timeUnit;

            changedV = drone.vMax * force;
            
            nextPos = drone.position + 0.5 * (changedV + drone.velocity) * self.timeUnit;
        end
            
        %   Calculate the total force of the field on the drone
        function f_total = getTotalForce(self,drone)
            f_att = self.attraction(drone.position,self.target,self.attBound,self.epsilon);
            f_rep = self.repulsion(drone,self.obstacles,self.repDist,self.etaR, self.etaV,self.target);
           

            f_total = f_att + f_rep;

            %f_total = self.util.getUnitVec(f_total);

            f_total = self.util.getNormalized(self.fAttMax, f_total);
        end

        function saveCSV(self,folder)
            writematrix(self.path, ['./',folder,'/pathMatrix'],'Delimiter',',');
            writematrix()
        end

    end
end

