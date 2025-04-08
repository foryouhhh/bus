function [shortestPaths, totalCosts] = k_paths(netCostMatrix, source, destination, k_path)  
  
if source > size(netCostMatrix,1) || destination > size(netCostMatrix,1)  
    warning('The source or destination node are not part of netCostMatrix');  
    shortestPaths=cell(1,k_path);        %定义最短路径为元胞数组
    totalCosts=zeros(1,k_path);  
else  
    k=1;  
    [path, cost] = dijkstra(netCostMatrix, source, destination);  
    %P是一个元胞数组，其中包含到目前为止找到的所有路径
    if isempty(path)  
        shortestPaths=cell(1,k_path);  
        totalCosts=zeros(1,k_path);  
    else  
        path_number = 1;   
        P{path_number,1} = path; P{path_number,2} = cost;   
        current_P = path_number;  
        %X是P子集的单元格数组（由下面的Yen算法使用）： 
        size_X=1;    
        X{size_X} = {path_number; path; cost};  

        S(path_number) = path(1); % 偏离顶点是最初的第一个顶点
   
        shortestPaths{k} = path;  
        totalCosts(k) = cost;  
  
        while (k < k_path  &&  size_X ~= 0 )  
            %从p路径中删除X元素
            for i=1:length(X)  
                if  X{i}{1} == current_P  
                    size_X = size_X - 1;  
                    X(i) = [];%删除该元胞  
                    break;  
                end  
            end  

            P_ = P{current_P,1}; %P_是当前的P，只是为了使符号更清晰  
  
            w = S(current_P);  
            for i = 1: length(P_)  
                if w == P_(i)  
                    w_index_in_path = i;  
                end  
            end  
  
  
            for index_dev_vertex= w_index_in_path: length(P_) - 1   %index_dev_vertex是偏差顶点P_中的索引 
                temp_netCostMatrix = netCostMatrix;  

                %删除P中index_dev_vertex之前的顶点以及其中的关联边
                for i = 1: index_dev_vertex-1  
                    v = P_(i);  
                    temp_netCostMatrix(v,:)=inf;  
                    temp_netCostMatrix(:,v)=inf;  
                end  

                %如果v在第k个最短路径中，且子路径与P_相似，则删除v的入射边  
                SP_sameSubPath=[];  
                index =1;  
                SP_sameSubPath{index}=P_;  
                for i = 1: length(shortestPaths)  
                    if length(shortestPaths{i}) >= index_dev_vertex  
                        if P_(1:index_dev_vertex) == shortestPaths{i}(1:index_dev_vertex)  
                            index = index+1;  
                            SP_sameSubPath{index}=shortestPaths{i};  
                        end  
                    end              
                end         
                v_ = P_(index_dev_vertex);  
                for j = 1: length(SP_sameSubPath)  
                    next = SP_sameSubPath{j}(index_dev_vertex+1);  
                    temp_netCostMatrix(v_,next)=inf;     
                end
  
                %得到顶点v之前的子路径的长度
                sub_P = P_(1:index_dev_vertex);  
                cost_sub_P=0;  
                for i = 1: length(sub_P)-1  
                    cost_sub_P = cost_sub_P + netCostMatrix(sub_P(i),sub_P(i+1));  
                end  
  
                %利用迪杰斯特拉算法获得最短路     
                [dev_p, c] = dijkstra(temp_netCostMatrix, P_(index_dev_vertex), destination);  
                if ~isempty(dev_p)  
                    path_number = path_number + 1;  
                    P{path_number,1} = [sub_P(1:end-1) dev_p] ;  %将子路径连接到顶点，再连接到目标 
                    P{path_number,2} =  cost_sub_P + c ;  
  
                    S(path_number) = P_(index_dev_vertex);  
  
                    size_X = size_X + 1;   
                    X{size_X} = {path_number;  P{path_number,1} ;P{path_number,2} };  
                else  
                    %warning('k=%d, isempty(p)==true!\n',k);  
                end        
            end  
            %否则，如果k大于可能路径的数量，则需要执行步骤
            %最后的结果将被重复！
            if size_X > 0  
                shortestXCost= X{1}{3};  %路径长度
                shortestX= X{1}{1};        %该路径索引  
                for i = 2 : size_X  
                    if  X{i}{3} < shortestXCost  
                        shortestX= X{i}{1};  
                        shortestXCost= X{i}{3};  
                    end  
                end  
                current_P = shortestX;  
                k = k+1;  
                shortestPaths{k} = P{current_P,1};  
                totalCosts(k) = P{current_P,2};  
            else  
                %k = k+1;  
            end  
        end  
    end  
end  
