// 添加站点输入框
function addStopInput() {
    const container = document.getElementById('stops-container');
    const stopDiv = document.createElement('div');
    stopDiv.className = 'stop-input';
    stopDiv.innerHTML = `
        <input type="text" placeholder="站点名称">
        <input type="number" placeholder="与上一站点距离(米)">
    `;
    container.appendChild(stopDiv);
}

// 添加乘客信息输入框
function addPassengerInput() {
    const container = document.getElementById('passengers-container');
    const passengerDiv = document.createElement('div');
    passengerDiv.className = 'passenger-input';
    passengerDiv.innerHTML = `
        <input type="text" placeholder="上车站点">
        <input type="text" placeholder="下车站点">
        <input type="number" placeholder="乘客数量">
    `;
    container.appendChild(passengerDiv);
}

// 开始仿真
async function startSimulation() {
    // 收集所有输入数据
    const stops = Array.from(document.querySelectorAll('.stop-input')).map(stop => ({
        name: stop.children[0].value,
        distance: parseFloat(stop.children[1].value) || 0
    }));

    // 计算每个站点的坐标（基于距离）
    let currentX = 0;
    const stopsWithCoords = stops.map(stop => {
        const x = currentX;
        currentX += stop.distance;
        return {
            name: stop.name,
            x: x,
            y: 0  // 所有站点在同一条直线上
        };
    });

    const simulationData = {
        buses: {
            count: document.getElementById('busCount').value,
            capacity: document.getElementById('busCapacity').value,
            maxSpeed: document.getElementById('busSpeed').value || 20
        },
        stops: stopsWithCoords,
        passengers: Array.from(document.querySelectorAll('.passenger-input')).map(passenger => ({
            fromStop: passenger.children[0].value,
            toStop: passenger.children[1].value,
            count: passenger.children[2].value
        }))
    };

    try {
        const response = await fetch('http://localhost:8080/api/simulate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(simulationData)
        });

        if (!response.ok) {
            throw new Error('仿真请求失败');
        }

        const result = await response.json();
        displaySimulationResults(result);
    } catch (error) {
        alert('仿真过程出错：' + error.message);
    }
}

// 显示仿真结果
function displaySimulationResults(results) {
    const container = document.getElementById('simulation-container');
    if (results.success) {
        container.innerHTML = `
            <h3>配置文件生成成功！</h3>
            <p>文件保存位置：${results.path}</p>
            <p>生成的文件：</p>
            <ul>
                <li>配置文件：${results.files.config}</li>
                <li>网络文件：${results.files.network}</li>
                <li>路线文件：${results.files.routes}</li>
                <li>节点文件：${results.files.nodes}</li>
                <li>边文件：${results.files.edges}</li>
                <li>GUI设置：${results.files.gui}</li>
            </ul>
            <p>请使用SUMO-GUI打开配置文件进行仿真。</p>
        `;
    } else {
        container.innerHTML = `
            <h3 style="color: red;">生成失败</h3>
            <p>错误信息：${results.error}</p>
        `;
    }
}