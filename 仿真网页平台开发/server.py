from flask import Flask, request, jsonify, send_from_directory
import os
from flask_cors import CORS
import sys

# 设置输出不缓冲
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)

print("开始导入所需模块...", flush=True)

# 获取当前文件所在目录的绝对路径
current_dir = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__, static_folder=current_dir)
CORS(app)

print("Flask应用创建成功", flush=True)

@app.route('/favicon.ico')
def favicon():
    return '', 204  # 返回"无内容"响应，避免404错误

@app.route('/')
def index():
    print("请求首页", flush=True)
    try:
        return send_from_directory(current_dir, 'index.html')
    except Exception as e:
        print(f"加载index.html失败: {str(e)}", flush=True)
        return str(e), 500

@app.route('/<path:path>')
def serve_static(path):
    print(f"请求文件: {path}", flush=True)
    try:
        return send_from_directory(current_dir, path)
    except Exception as e:
        print(f"加载文件{path}失败: {str(e)}", flush=True)
        return str(e), 404

def create_sumo_config(data):
    """创建SUMO配置文件"""
    try:
        # 获取桌面路径
        desktop_path = os.path.join(os.path.expanduser("~"), "Desktop", "sumo_simulation")
        
        # 如果文件夹不存在则创建
        if not os.path.exists(desktop_path):
            os.makedirs(desktop_path)
        
        # 创建节点文件
        nodes_file = os.path.join(desktop_path, "nodes.nod.xml")
        with open(nodes_file, 'w', encoding='utf-8') as f:
            f.write("""<?xml version="1.0" encoding="UTF-8"?>
<nodes xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/nodes_file.xsd">
""")
            # 为每个站点创建节点
            for i, stop in enumerate(data['stops']):
                f.write(f'    <node id="stop{i}" x="{stop["x"]}" y="{stop["y"]}" type="priority"/>\n')
            f.write("</nodes>")
            
        # 创建边文件
        edges_file = os.path.join(desktop_path, "edges.edg.xml")
        with open(edges_file, 'w', encoding='utf-8') as f:
            f.write("""<?xml version="1.0" encoding="UTF-8"?>
<edges xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/edges_file.xsd">
""")
            # 创建站点之间的连接
            for i in range(len(data['stops'])-1):
                # 添加站点标识
                f.write(f'    <edge id="edge{i}to{i+1}" from="stop{i}" to="stop{i+1}" numLanes="1" speed="13.89" priority="1" allow="all" length="100">\n')
                f.write(f'        <param key="name" value="{data["stops"][i]["name"]}"/>\n')
                f.write('    </edge>\n')
                f.write(f'    <edge id="edge{i+1}to{i}" from="stop{i+1}" to="stop{i}" numLanes="1" speed="13.89" priority="1" allow="all" length="100">\n')
                f.write(f'        <param key="name" value="{data["stops"][i+1]["name"]}"/>\n')
                f.write('    </edge>\n')
            f.write("</edges>")
            
        # 使用netconvert生成网络文件
        net_file = os.path.join(desktop_path, "school_bus.net.xml")
        os.system(f'netconvert --node-files="{nodes_file}" --edge-files="{edges_file}" --output-file="{net_file}" --sidewalks.guess')
        
        # 创建additional文件
        additional_file = os.path.join(desktop_path, "additional.xml")
        with open(additional_file, "w", encoding='utf-8') as f:
            f.write("""<?xml version="1.0" encoding="UTF-8"?>
<additional xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/additional_file.xsd">
""")
            # 为每个站点创建停靠点和检测器
            for i in range(len(data['stops'])-1):
                stop = data['stops'][i]
                # 创建公交站
                f.write(f"""    <!-- 站点 {stop['name']} -->
    <busStop id="stop_{i}" lane="edge{i}to{i+1}_0" startPos="10" endPos="40" name="{stop['name']}" lines="bus_route" friendlyPos="true">
        <param key="capacity" value="5"/>
    </busStop>

    <!-- 站点信息显示 -->
    <chargingStation id="info_{i}" lane="edge{i}to{i+1}_0" startPos="10" endPos="40" name="{stop['name']}" power="0" efficiency="0" chargeInTransit="0">
        <param key="name" value="{stop['name']}"/>
        <param key="waiting" value="0"/>
    </chargingStation>
""")
            f.write("</additional>")
        
        # 创建路线文件
        route_file = os.path.join(desktop_path, "school_bus.rou.xml")
        with open(route_file, "w", encoding='utf-8') as f:
            f.write("""<?xml version="1.0" encoding="UTF-8"?>
<routes xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/routes_file.xsd">
    <!-- 定义车辆类型 -->
    <vType id="schoolBus" vClass="bus" length="12" maxSpeed="{}" accel="2.6" decel="4.5" sigma="0.5" personCapacity="{}" color="1,1,0"/>

    <!-- 定义公交线路 -->
    <route id="bus_route" edges="{}"/>
""".format(float(data['buses']['maxSpeed'])/3.6, data['buses']['capacity'],
           " ".join([f"edge{j}to{j+1}" for j in range(len(data['stops'])-1)])))
            
            # 生成车辆
            for i in range(int(data['buses']['count'])):
                f.write(f"""
    <!-- 校车 {i+1} -->
    <vehicle id="bus_{i}" type="schoolBus" route="bus_route" depart="{i*180}">
        <!-- 在每个站点停靠30秒 -->
""")
                # 添加每个站点的停靠
                for j in range(len(data['stops'])-1):
                    f.write(f'        <stop busStop="stop_{j}" duration="30" until="86400" parking="true" triggered="false"/>\n')
                f.write("    </vehicle>\n")
            
            # 生成乘客流
            for i, passenger in enumerate(data['passengers']):
                # 找到上下车站点的索引
                from_stop = next(i for i, s in enumerate(data['stops']) if s['name'] == passenger['fromStop'])
                to_stop = next(i for i, s in enumerate(data['stops']) if s['name'] == passenger['toStop'])
                
                # 为每个乘客组生成对应数量的乘客
                for j in range(int(passenger['count'])):
                    # 生成起点和终点之间的所有边
                    edges = []
                    if from_stop < to_stop:
                        for k in range(from_stop, to_stop):
                            edges.append(f"edge{k}to{k+1}")
                    else:
                        for k in range(from_stop, to_stop, -1):
                            edges.append(f"edge{k}to{k-1}")
                    
                    edges_str = " ".join(edges)
                    f.write(f"""    
    <!-- 乘客 {i}_{j} -->
    <person id="person_{i}_{j}" depart="{i*100 + j*10}">
        <walk edges="{edges_str}"/>
    </person>
""")
            
            f.write("</routes>")
        
        # 创建配置文件
        config_file = os.path.join(desktop_path, "school_bus.sumocfg")
        with open(config_file, "w", encoding='utf-8') as f:
            f.write(f"""<?xml version="1.0" encoding="UTF-8"?>
<configuration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://sumo.dlr.de/xsd/sumoConfiguration.xsd">
    <input>
        <net-file value="school_bus.net.xml"/>
        <route-files value="school_bus.rou.xml"/>
        <additional-files value="additional.xml"/>
    </input>
    <time>
        <begin value="0"/>
        <end value="3600"/>
        <step-length value="1.0"/>
    </time>
    <processing>
        <ignore-route-errors value="true"/>
        <time-to-teleport value="-1"/>
        <waiting-time-memory value="3600"/>
    </processing>
    <report>
        <verbose value="true"/>
        <no-step-log value="true"/>
        <duration-log.statistics value="true"/>
    </report>
    <gui_only>
        <gui-settings-file value="gui-settings.xml"/>
        <start value="true"/>
        <quit-on-end value="false"/>
    </gui_only>
</configuration>
""")

        # 创建GUI设置文件
        gui_settings_file = os.path.join(desktop_path, "gui-settings.xml")
        with open(gui_settings_file, "w", encoding='utf-8') as f:
            f.write("""<?xml version="1.0" encoding="UTF-8"?>
<viewsettings>
    <scheme name="real world"/>
    <delay value="100"/>
    <viewport zoom="100" x="0" y="0"/>
    <decal filename=""/>
    <scheme name="custom">
        <opengl antialiase="0" dither="0"/>
        <background backgroundColor="white" showGrid="0" gridXSize="100.00" gridYSize="100.00"/>
        <edges laneShowBorders="1" showLinkDecals="1" showRails="1" hideConnectors="0"
               edgeName_show="1" edgeName_size="50.00" edgeName_color="orange"
               internalEdgeName_show="0" streetName_show="0" cwaEdgeName_show="0"/>
        <vehicles vehicleName_show="0" vehicleValue_show="0" vehicleText_show="0"
                 showBlinker="1" drawLaneChangePreference="0" showBTRange="0"
                 showRouteIndex="0" scaleLength="1.00" showParkingInfo="1"/>
        <persons personName_show="1" personValue_show="1"/>
        <junctions junctionName_show="0" junctionIndex_show="0" showLane2Lane="0" drawShape="1" drawCrossingsAndWalkingareas="1"/>
        <additionals addName_show="1" addFullName_show="1" busStopName_show="1" busStopName_size="50.00" busStopName_color="blue"/>
        <legend showSizeLegend="1" showColorLegend="0"/>
    </scheme>
</viewsettings>
""")
        
        print(f"配置文件已生成在桌面的 sumo_simulation 文件夹中：{desktop_path}", flush=True)
        return desktop_path
        
    except Exception as e:
        print(f"创建配置文件时出错：{str(e)}", flush=True)
        raise

@app.route('/api/simulate', methods=['POST'])
def simulate():
    try:
        data = request.json
        print("收到请求数据:", data, flush=True)
        
        # 创建SUMO配置文件
        desktop_path = create_sumo_config(data)
        
        return jsonify({
            "success": True, 
            "message": "配置文件已生成",
            "path": desktop_path,
            "files": {
                "config": "school_bus.sumocfg",
                "network": "school_bus.net.xml",
                "routes": "school_bus.rou.xml",
                "nodes": "nodes.nod.xml",
                "edges": "edges.edg.xml",
                "additional": "additional.xml",
                "gui": "gui-settings.xml"
            }
        })
            
    except Exception as e:
        print(f"处理请求时出错: {str(e)}", flush=True)
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    try:
        # 设置输出不缓冲
        sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
        
        print("\n=== 校车仿真系统服务器 ===", flush=True)
        print("准备启动服务器...", flush=True)
        port = 8080
        print(f"正在启动服务器，监听地址: http://localhost:{port}", flush=True)
        print(f"Python版本: {sys.version}", flush=True)
        print(f"当前工作目录: {os.getcwd()}", flush=True)
        print(f"静态文件目录: {current_dir}", flush=True)
        print("\n请在浏览器中访问: http://localhost:8080", flush=True)
        print("按Ctrl+C可以停止服务器", flush=True)
        print("="*30, flush=True)
        
        # 设置Flask的运行参数
        app.run(
            debug=False,  # 关闭debug模式
            host='0.0.0.0',
            port=port,
            use_reloader=False  # 禁用重载器
        )
    except Exception as e:
        print(f"\n服务器启动失败: {str(e)}", flush=True)
        input("按Enter键退出...") 