function [shortestPath, totalCost] = dijkstra(netCostMatrix, s, d)

n = size(netCostMatrix,1);
for i = 1:n
    % 初始化最远的前一跳节点为其本身
    farthestPrevHop(i) = i; % 用于计算RTS/CTS范围
    farthestNextHop(i) = i;
end

% 所有节点初始化为未访问
visited(1:n) = false;

% 存储各节点到源节点的最短距离
distance(1:n) = inf;    
parent(1:n) = 0;

distance(s) = 0;
for i = 1:(n-1)
    temp = [];
    for h = 1:n
         if ~visited(h)  % 未加入最短路径树
             temp=[temp distance(h)];
         else
             temp=[temp inf];
         end
    end
     [t, u] = min(temp);      % 选取当前距离最小的未访问节点
     visited(u) = true;         % 标记为已访问
     for v = 1:n                % 遍历节点u的所有邻居节点
         if ( ( netCostMatrix(u, v) + distance(u)) < distance(v) )
             distance(v) = distance(u) + netCostMatrix(u, v);   % 当找到更短路径时，更新最短距离
             parent(v) = u;     % 更新父节点
         end             
     end
end

shortestPath = [];
if parent(d) ~= 0   % 若存在最短路径
    t = d;
    shortestPath = d;
    while t ~= s
        p = parent(t);
        shortestPath = [p shortestPath];
        
        if netCostMatrix(t, farthestPrevHop(t)) < netCostMatrix(t, p)
            farthestPrevHop(t) = p;
        end
        if netCostMatrix(p, farthestNextHop(p)) < netCostMatrix(p, t)
            farthestNextHop(p) = t;
        end

        t = p;      
    end
end

totalCost = distance(d);