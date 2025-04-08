% 初始化
clc, clear, close all

% 导入输入数据
stop = readmatrix("data.xlsx", "Sheet", "Sheet1", "Range", "C2:BE56"); % 站台无权重邻接矩阵
travel_time = readmatrix("data.xlsx", "Sheet", "Sheet1", "Range", "BF2:DH56"); % 旅行时间
ind = find(travel_time==0);
travel_time(ind) = inf;
f = readmatrix("data.xlsx", "Sheet", "Sheet1", "Range", "B2:B56"); % 每个车站所需接收学生数量

%% stage 1, 确定最小车辆数

cap = 36;
dem = sum(f);
num_car = floor(dem/cap) + 1;

%% stage 2, 得到初始可行解

pickup_stop = cell(3,1); % 储存车辆接收学生停靠的站台
pickup_every_stop = cell(3,1); % 存放每辆车在每个站台接收的学生
current_cap = cap * ones(num_car, 1); % 车辆的剩余容量
dist_des = zeros(55, 1); % 每个车站距终点的距离
bus_path = cell(3,1); % 每个车辆的路径
f_copy = f;
for i = 1:55
    [~, dist_des(i)] = dijkstra(travel_time, i, 55);
end

% 生成服从以原行程时间为均值的右半标准正态分布的实际行程时间
actual_travel_time = travel_time + abs(randn(size(travel_time)));
actual_travel_time = max(actual_travel_time, travel_time);

% 确保新的总实际行程时间不超过原总行程时间加上600秒
max_additional_time = 600;
original_total_time = sum(travel_time(:));

for k = 1:num_car
    k_path = 1;
    [~, index] = max(dist_des .* (f~=0));
    while 1
        [k_routes, t_cost] = k_paths(actual_travel_time, index, 55, k_path);
        if sum(t_cost) > original_total_time + max_additional_time
            fprintf('路径 %d 超过最大允许时间，重新规划\n', k);
            k_path = k_path + 1;
            continue;
        end
        pickup_stop{k} = [];
        pickup_every_stop{k} = zeros(55, 1);
        if length(k_routes) ~= k_path
            fprintf("不存在第%d距离短的道路\n", k_path);
            break;
        end
        for i = 1:length(k_routes{k_path})
            if current_cap(k) >= f_copy(k_routes{k_path}(i)) && f_copy(k_routes{k_path}(i)) ~= 0
                current_cap(k) = current_cap(k) - f_copy(k_routes{k_path}(i));
                pickup_every_stop{k}(k_routes{k_path}(i)) =  f_copy(k_routes{k_path}(i));
                f_copy(k_routes{k_path}(i)) = 0;
                pickup_stop{k} = [pickup_stop{k}, k_routes{k_path}(i)];
            elseif current_cap(k) < f_copy(k_routes{k_path}(i)) && f_copy(k_routes{k_path}(i)) ~= 0
                f_copy(k_routes{k_path}(i)) = f_copy(k_routes{k_path}(i)) - current_cap(k);
                pickup_every_stop{k}(k_routes{k_path}(i)) = current_cap(k);
                current_cap(k) = 0;
                pickup_stop{k} = [pickup_stop{k}, k_routes{k_path}(i)];
                break;
            elseif sum(f_copy) == 0
                break;
            end
        end
        if sum(f_copy) == 0 || current_cap(k) == 0
            break;
        end
        f_copy = f;
        current_cap(k) = cap;
        k_path = k_path + 1;
    end
    f = f_copy;
    bus_path{k} = k_routes{k_path};
end

% 输出每条路线的信息
for k = 1:num_car
    fprintf('车辆 %d 的路线: ', k);
    disp(bus_path{k});
    fprintf('剩余容量: %d\n', current_cap(k));
    % 计算并输出每条路线的总实际行程时间和原总行程时间
    actual_time = sum(actual_travel_time(sub2ind(size(actual_travel_time), bus_path{k}(1:end-1), bus_path{k}(2:end))));
    original_time = sum(travel_time(sub2ind(size(travel_time), bus_path{k}(1:end-1), bus_path{k}(2:end))));
    fprintf('总实际行程时间: %.2f 秒\n', actual_time);
    fprintf('原总行程时间: %.2f 秒\n', original_time);
    % 输出每个站点之间的实际用时
    fprintf('各站点之间的实际用时: ');
    for j = 1:length(bus_path{k})-1
        segment_time = actual_travel_time(bus_path{k}(j), bus_path{k}(j+1));
        fprintf('%.2f ', segment_time);
    end
    fprintf('秒\n');
end

%% stage3 调整初始可行解

for j = num_car:-1:1
    if j == 1
        break;
    end
    if current_cap(j) ~= 0
        for h = 1:j-1
            for iter = 1:length(bus_path{j})
                if ~isempty(find(pickup_stop{h}==bus_path{j}(iter), 1)) && bus_path{j}(iter) ~= 55 ...
                    && ~isempty(find(pickup_stop{j}==bus_path{j}(iter), 1))
                    max_trans = current_cap(j) - current_cap(h);
                    if pickup_every_stop{h}(bus_path{j}(iter)) <= max_trans && ...
                            pickup_every_stop{h}(bus_path{j}(iter)) ~= 0
                        pickup_every_stop{j}(bus_path{j}(iter)) = pickup_every_stop{j}(bus_path{j}(iter))...
                            + pickup_every_stop{h}(bus_path{j}(iter));
                        current_cap(j) = current_cap(j) - pickup_every_stop{h}(bus_path{j}(iter));
                        current_cap(h) = current_cap(h) + pickup_every_stop{h}(bus_path{j}(iter));
                        pickup_every_stop{h}(bus_path{j}(iter)) = 0;
                    elseif pickup_every_stop{h}(bus_path{j}(iter)) > max_trans
                        pickup_every_stop{j}(bus_path{j}(iter)) = pickup_every_stop{j}(bus_path{j}(iter)) + max_trans;
                        current_cap(j) = current_cap(j) - max_trans;
                        current_cap(h) = current_cap(h) + max_trans;
                        pickup_every_stop{h}(bus_path{j}(iter)) = pickup_every_stop{h}(bus_path{j}(iter)) - max_trans;
                    end
                elseif ~isempty(find(bus_path{h} == bus_path{j}(iter), 1)) && bus_path{j}(iter)~= 55
                    max_trans = current_cap(j) - current_cap(h);
                    if pickup_every_stop{h}(bus_path{j}(iter)) ~= 0 && ...
                            pickup_every_stop{h}(bus_path{j}(iter)) <= max_trans
                        pickup_every_stop{j}(bus_path{j}(iter)) = pickup_every_stop{j}...
                            (bus_path{j}(iter)) + pickup_every_stop{h}(bus_path{j}(iter));
                        current_cap(j) = current_cap(j) - pickup_every_stop{h}(bus_path{j}(iter));
                        current_cap(h) = current_cap(h) + pickup_every_stop{h}(bus_path{j}(iter));
                        pickup_every_stop{h}(bus_path{j}(iter)) = 0;
                    end
                end
            end
        end
        if current_cap(j) == 0
            break;
        end
    end
end


%% stage 4
% 对车辆在每站接收的人数进行判断，若存在0则说明车辆路径有所变化，此时对路径重新规划

change_stop = cell(3,1); % 存放接收的人数为0的前一站台
for k = 1:num_car
    temp = pickup_stop{k}(pickup_every_stop{k}(pickup_stop{k}) == 0);
    if ~isempty(temp)
        change_stop{k} = bus_path{k}(find(bus_path{k}==temp)-1);
        [shorter_path, ~] = dijkstra(travel_time, change_stop{k}, 55);
        bus_path{k}(find(bus_path{k}==change_stop{k}):end) = [];
        bus_path{k} = [bus_path{k}, shorter_path];
    end
end

%% stage 5
% 对于具有相同容量的公交车，使用Hungarian算法解决适当的分配问题
% 由于缺乏车辆停车点信息，因此该stage不进行运算

% u = [];
% B = Hungarian(A);
% [~,b] = linear_assignment(u,B);


%% 性能测试

adj_matrix = cell(3,1);
z = cell(3,1);
travel_time(ind) = 0;
obj2 = 0;
obj3 = zeros(num_car, 1);
for i = 1:num_car
    z{i} = pickup_every_stop{i}~=0;
    adj_matrix{i} = zeros(55);
    for j = 2:length(bus_path{i})
        adj_matrix{i}(bus_path{i}(j-1), bus_path{i}(j)) = 1;
    end
end
for k = 1:num_car
    for i = 1:54
        for j = 1:55
            obj2 = obj2 + travel_time(i,j) * adj_matrix{k}(i,j) * sum(z{k}(1:i));
            obj3(k) = obj3(k) + (travel_time(i,j)*adj_matrix{k}(i,j)) / 60;
        end
        obj2 = obj2 + 25 * z{k}(i) * sum(z{k}(1:i));
        obj3(k) = obj3(k) + 25 * z{k}(i) / 60;
    end
end
