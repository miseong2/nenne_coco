import asyncio
import json
import os
import subprocess
import time

# 네트워크 및 서버 통신 라이브러리
import requests
from bless import BlessServer, GATTCharacteristicProperties, GATTAttributePermissions
import websockets
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCConfiguration, RTCIceServer
from aiortc.contrib.media import MediaStreamTrack
import av  # PyAV 라이브러리

# AI 비전 및 하드웨어 제어 라이브러리 
import cv2
from ultralytics import YOLO
import Jetson.GPIO as GPIO



# 네트워크 설정
CLOUD_SERVER_URL = "https://infantserver-1073747594853.asia-northeast3.run.app"
CONFIG_FILE = "wifi_config.json"
SERVICE_UUID = "A07498CA-AD5B-474E-940D-16F1FBE7E8CD"
CHAR_UUID = "B07498CA-AD5B-474E-940D-16F1FBE7E8CD"
DEVICE_NAME_FOR_SERVER = "jetson-001"

# AI 비전 및 하드웨어 설정
SENSOR_PIN = 18
USB_CAM_ID = 1
CSI_CAM_ID = 0
HOME = os.path.expanduser("~")
MODEL_PATH_USB = os.path.join(HOME, "Desktop/my_baby_monitor/train/weights/best.engine")
MODEL_PATH_IR = "/home/kjw/Desktop/my_baby_monitor/project_files/quakquak-3/runs/detect/train4/weights/best.engine"

# 위험 감지 로직 설정
DANGER_HOLD_SEC = 60.0
RESET_GRACE_PERIOD_SEC = 3.0
CLASS_KEYWORDS = { "baby": ["baby"], "mouth": ["mouth"], "nose": ["nose"], "pacifier": ["pacifier"] }


# Wi-Fi 및 블루투스 설정 관련 함수
def save_wifi_config(ssid, password):
    with open(CONFIG_FILE, "w") as f:
        json.dump({"ssid": ssid, "password": password}, f)
    print(f"Wi-Fi 정보 저장 완료: {ssid}")

def load_wifi_config():
    with open(CONFIG_FILE, "r") as f:
        return json.load(f)

def connect_to_wifi(ssid, password):
    print(f"{ssid}에 연결을 시도합니다...")
    try:
        subprocess.run(["sudo", "nmcli", "dev", "wifi", "connect", ssid, "password", password], check=True, timeout=20)
        print("Wi-Fi 연결 성공!")
        return True
    except Exception as e:
        print(f"Wi-Fi 연결 실패: {e}")
        return False

async def run_ble_setup_server():
    server = BlessServer(name="BLE-Setup")
    await server.add_new_service(SERVICE_UUID)
    props = (GATTCharacteristicProperties.write | GATTCharacteristicProperties.write_without_response)
    await server.add_new_characteristic(SERVICE_UUID, CHAR_UUID, props, None, GATTAttributePermissions.writeable)
    def on_write(_, value: bytearray, **kwargs):
        try:
            data = json.loads(bytearray(value).decode("utf-8"))
            ssid, pwd = data.get("ssid"), data.get("password")
            if ssid and pwd:
                print("앱으로부터 Wi-Fi 정보 수신:", ssid)
                save_wifi_config(ssid, pwd)
                print("설정 완료. 재부팅을 진행해주세요.")
        except Exception as e:
            print("쓰기 데이터 처리 오류:", e)
    server.write_request_func = on_write
    await server.start()
    print("BLE 설정 모드 시작. 앱의 연결을 기다립니다...")
    await asyncio.get_running_loop().create_future()

# WebRTC 및 AI 비전 모니터링 관련 함수 
class OpenCVVideoStreamTrack(MediaStreamTrack):
    kind = "video"
    def __init__(self):
        super().__init__()
        self.frame = None
    async def recv(self):
        pts, time_base = await self.next_timestamp()
        if self.frame is not None:
            video_frame = av.VideoFrame.from_ndarray(self.frame, format="bgr24")
            video_frame.pts = pts
            video_frame.time_base = time_base
            return video_frame
        await asyncio.sleep(0.01)
        return await self.recv()

def send_danger_alert(device_name, danger_type):
    payload = {"deviceId": device_name, "danger": danger_type}
    headers = {"Content-Type": "application/json"}
    try:
        response = requests.post(f"{CLOUD_SERVER_URL}/api/alert", headers=headers, data=json.dumps(payload))
        if response.status_code == 200:
            print(f"클라우드 서버로 알림 전송 성공: {danger_type}")
        else:
            print(f"클라우드 서버 전송 실패: {response.status_code}")
    except Exception as e:
        print(f"클라우드 서버 연결 오류: {e}")

def gstreamer_pipeline_usb(device_id=1):
    return (f"v4l2src device=/dev/video{device_id} ! videoconvert ! video/x-raw, format=(string)BGR ! appsink")

def gstreamer_pipeline_csi(sensor_id=0, flip_method=0):
    return (f"nvarguscamerasrc sensor-id={sensor_id} ! nvvidconv flip-method={flip_method} ! video/x-raw, format=(string)BGRx ! videoconvert ! video/x-raw, format=(string)BGR ! appsink")

def setup_gpio():
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    print(f"GPIO 핀 {SENSOR_PIN}이 조도 센서용으로 초기화되었습니다.")

def find_class_indices(names_dict):
    inv = {i: str(n).lower() for i, n in names_dict.items()}
    found = {"baby": None, "mouth": None, "nose": None, "pacifier": None}
    for key, patterns in CLASS_KEYWORDS.items():
        for idx, nm in inv.items():
            if any(pat.lower() in nm for pat in patterns):
                found[key] = idx
                break
    return found

async def start_monitoring():
    print("Wi-Fi 운영 모드를 시작합니다.")
    
    pc = None
    video_track = OpenCVVideoStreamTrack()
    
    # WebRTC 시그널링을 위한 별도의 비동기 함수
    async def run_signaling_client():
        nonlocal pc
        websocket_url = f"{CLOUD_SERVER_URL.replace('https', 'wss')}/api/ws"
        while True:
            try:
                async with websockets.connect(websocket_url) as websocket:
                    print("✅ 시그널링 서버에 연결되었습니다.")
                    await websocket.send(json.dumps({"type": "register", "deviceId": DEVICE_NAME_FOR_SERVER}))
                    async for message in websocket:
                        data = json.loads(message)
                        if data.get("type") == "offer":
                            print("\n📱 [로그] 앱으로부터 실시간 영상 요청(Offer)을 수신했습니다. WebRTC P2P 연결을 시작합니다.\n")
                            ice_servers = [RTCIceServer(urls=["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"])]
                            config = RTCConfiguration(iceServers=ice_servers)
                            pc = RTCPeerConnection(configuration=config)
                            pc.addTrack(video_track)
                            @pc.on("iceconnectionstatechange")
                            async def on_iceconnectionstatechange():
                                print(f"ICE Connection State is {pc.iceConnectionState}")
                            await pc.setRemoteDescription(RTCSessionDescription(sdp=data["sdp"], type=data["type"]))
                            answer = await pc.createAnswer()
                            await pc.setLocalDescription(answer)
                            await websocket.send(json.dumps({"type": "answer", "sdp": pc.localDescription.sdp, "deviceId": data.get("senderId")}))
            except (websockets.ConnectionClosed, ConnectionRefusedError):
                print("시그널링 서버와 연결이 끊겼습니다.")
            except Exception as e:
                print(f"시그널링 서버 연결 실패: {e}")
            print("5초 후 재연결을 시도합니다...")
            await asyncio.sleep(5)

    # 모니터링을 위한 별도의 비동기 함수
    async def run_monitoring_loop():
        nonlocal video_track
        print("AI 모델 로딩 및 실시간 감시를 시작합니다...")
        try:
            GPIO.cleanup()
        except Exception:
            pass
        setup_gpio()
        risk_start_time = None
        cap, model, current_mode = None, None, None
        class_idx = {"baby": 0, "mouth": 1, "nose": 2, "pacifier": 3}
        class_idx_resolved = False
        last_sent_status = "SAFE"
        risk_reset_timer_start = None
        while True:
            try:
                desired_mode = "dark" if GPIO.input(SENSOR_PIN) == GPIO.HIGH else "bright"
                if desired_mode != current_mode:
                    print(f"'{desired_mode.upper()}' 모드로 전환합니다.")
                    if cap: cap.release()
                    pipeline = (gstreamer_pipeline_csi(CSI_CAM_ID) if desired_mode == "dark" else gstreamer_pipeline_usb(USB_CAM_ID))
                    model_path = MODEL_PATH_IR if desired_mode == "dark" else MODEL_PATH_USB
                    try:
                        model = YOLO(model_path)
                        class_idx_resolved = False
                    except Exception as e:
                        print(f"모델 로드 오류: {e}")
                        await asyncio.sleep(2)
                        continue
                    cap = cv2.VideoCapture(pipeline, cv2.CAP_GSTREAMER)
                    if not cap.isOpened():
                        print("카메라 열기 실패.")
                        current_mode = None
                        await asyncio.sleep(2)
                        continue
                    print("카메라 및 모델 전환 성공!")
                    current_mode = desired_mode
                if cap and model:
                    ret, frame = cap.read()
                    if not ret:
                        print("프레임 읽기 실패.")
                        current_mode = None
                        await asyncio.sleep(1)
                        continue
                    video_track.frame = frame.copy()
                    results = model(frame, conf=0.5, verbose=False)
                    r0 = results[0]
                    if not class_idx_resolved and hasattr(r0, "names"):
                        resolved = find_class_indices(r0.names)
                        for k, v in resolved.items():
                            if v is not None: class_idx[k] = v
                        class_idx_resolved = True
                        print(f"[클래스 매핑 완료] {class_idx}")
                    detected_cls = ({int(c) for c in r0.boxes.cls.tolist()} if r0.boxes.cls is not None else set())
                    baby_seen = class_idx["baby"] in detected_cls
                    mouth_seen = class_idx["mouth"] in detected_cls
                    nose_seen = class_idx["nose"] in detected_cls
                    pacifier_seen = class_idx["pacifier"] in detected_cls
                    risk_condition = (baby_seen and not mouth_seen and not nose_seen and not pacifier_seen)
                    now = time.time()
                    if risk_condition:
                        if risk_start_time is None:
                            risk_start_time = now
                            print(f"[{time.strftime('%H:%M:%S')}] 위험 조건 감지 시작.")
                        risk_reset_timer_start = None
                    elif risk_start_time is not None:
                        if risk_reset_timer_start is None:
                            risk_reset_timer_start = now
                        if (now - risk_reset_timer_start) >= RESET_GRACE_PERIOD_SEC:
                            print(f"[{time.strftime('%H:%M:%S')}] 위험 타이머 초기화.")
                            risk_start_time = None
                    current_status = "SAFE"
                    if risk_start_time is not None:
                        elapsed = now - risk_start_time
                        current_status = "DANGER" if elapsed >= DANGER_HOLD_SEC else "WARNING"
                    if current_status != last_sent_status:
                        print(f"상태 변경: {last_sent_status} -> {current_status}")
                        if current_status == "DANGER":
                            send_danger_alert(DEVICE_NAME_FOR_SERVER, "얼굴 가려짐 위험 감지")
                        last_sent_status = current_status
                await asyncio.sleep(0.001)
            except Exception as e:
                print(f"모니터링 루프에서 오류 발생: {e}")
                await asyncio.sleep(5) # 오류 발생 시 5초 대기 후 재시도

    try:
        await asyncio.gather(
            run_signaling_client(),
            run_monitoring_loop()
        )
    except (KeyboardInterrupt, asyncio.CancelledError):
        print("\n프로그램을 중단합니다.")
    finally:
        print("정리 작업 시작...")
        GPIO.cleanup()
        print("모든 자원이 해제되었습니다.")

if __name__ == "__main__":
    if os.path.exists(CONFIG_FILE):
        config = load_wifi_config()
        if connect_to_wifi(config["ssid"], config["password"]):
            asyncio.run(start_monitoring())
        else:
            print("저장된 정보로 Wi-Fi에 연결할 수 없습니다.")
    else:
        print(f"'{CONFIG_FILE}'을 찾을 수 없습니다. BLE 설정 모드를 시작합니다.")
        try:
            asyncio.run(run_ble_setup_server())
        except KeyboardInterrupt:
            pass