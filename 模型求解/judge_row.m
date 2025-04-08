function flag = judge_row(X1, X2, iter)
    flag = 0;
    stop = X2(iter);
    path = X2(iter:end);
    start = find(X1 == stop);
    if isequal(X1(start:end), path)
        flag = 1;
    end

end