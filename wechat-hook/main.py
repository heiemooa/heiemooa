import codecs
import contextlib
import json
import os
import time
from datetime import datetime
from dotenv import load_dotenv

import frida
import jsondiff
import requests

load_dotenv()  # 这会自动从项目根目录的 .env 文件加载环境变量

def sort_departments(departments):
    for department in departments:
        sort_department(department)
    return sorted(departments, key=lambda d: d['chineseName'])


def sort_department(department):
    department['subDepartments'] = sort_departments(department['subDepartments'])
    department['users'] = sorted(department['users'], key=lambda u: u['name'])
    return department


class State(object):

    def __init__(self, state):
        self._now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        self._state = sort_departments(state)

        # 读取环境变量（如果不存在则抛出异常）
        self.WECHAT_BOT_KEY = os.environ["WECHAT_BOT_KEY"]  # 不存在会报 KeyError
        
    def save(self):
        with open(f'.files/{self._now}.json', 'w') as f:
            json.dump(self._state, f, ensure_ascii=False, indent=2)

    def diff(self, prev):
        return jsondiff.diff(prev, self._state, syntax='symmetric', marshal=True)

    def raw(self):
        return self._state


@contextlib.contextmanager
def wecom_session():
    session = frida.attach('企业微信')
    yield session

    session.detach()


@contextlib.contextmanager
def load_script(agent):
    with codecs.open(agent, 'r', 'utf-8') as f:
        with wecom_session() as session:
            script = session.create_script(f.read())
            script.load()

            yield script


def fetch_state():
    with load_script('./agent.js') as script:
        return State(script.exports_sync.fetch())


def prev_state():
    files = os.listdir('.files')
    if files:
        with codecs.open(f'.files/{max(files)}', 'r', 'utf-8') as f:
            return json.load(f)
    return None


def diff_state():
    prev = prev_state()
    curr = fetch_state()  # type: State
    curr_users = coll_users(curr.raw())

    diff = curr.diff(prev)
    if prev is None or diff:
        curr.save()
        if prev is not None:
            return list(summary(prev, curr.raw(), diff, curr_users=curr_users, prev_users=coll_users(prev)))


def summary(prev, curr, diff, path=None, prev_key=None, curr_users=None, prev_users=None):
    if isinstance(diff, dict) and 'userId' in diff:
        path, _ = pop_path(path)
        insert = {}
        remove = {}
        for k, v in diff.items():
            remove[k] = v[0]
            insert[k] = v[1]
        diff = {'$insert': [(prev_key, insert)], '$delete': [(prev_key, remove)]}

    for k, v in diff.items():
        if isinstance(k, str) and k.startswith('$'):
            act = k.lstrip('$')
            if k == '$delete':
                act = '删除'
            elif k == '$insert':
                act = '增加'

            for item in v:
                pre, suf, desc = '', '', ''
                idx, val = item
                if 'title' in val or 'userId' in val:
                    if val['name'] not in prev_users:
                        act = '新入职'
                        pre, suf = '<font color="info">', '</font>'
                    if val['name'] not in curr_users:
                        act = '离职'
                        pre, suf = '<font color="warning">', '</font>'
                        desc = f' 入职时间是 <{find_first_join_time(val["name"])}>'
                    if 'title' not in val:
                        val['title'] = 'Unknown'

                    yield f'{pre}在 [{path}] 中, {act}一个成员: <{val["name"]}> 职位是 <{val["title"]}>{desc}{suf}'
                else:
                    yield f'在 [{path}] 中, {act}一个部门: <{val["chineseName"]}>'
        elif isinstance(v, dict):
            prev_next, curr_next = next_pair(prev, curr, k)
            yield from summary(prev_next, curr_next, v, join_name(path, curr, k), k, curr_users, prev_users)
        elif isinstance(v, list):
            if k == 'title':
                path, name = pop_path(path)
                yield f'在 [{path}] 中, <{name}> 的职位从 <{v[0]}> 修改为 <{v[1]}>'
            elif k == 'chineseName':
                path, name = pop_path(path)
                yield f'在 [{path}] 中, 部门 <{v[0]}> 的名称修改为 <{v[1]}>'
            elif k == 'realname':
                path, name = pop_path(path)
                yield f'在 [{path}] 中, <{name}> 的真名修改为 <{v[1]}>'
            elif k == 'departmentId':
                path, name = pop_path(path)
            else:
                yield f'在 [{path}] 中, <{k}> 发生了变化: {v}'


def find_first_join_time(name):
    files = sorted(os.listdir('.files'))
    if files:
        for i, file in enumerate(files):
            with codecs.open(f'.files/{file}', 'r', 'utf-8') as f:
                if name in coll_users(json.load(f)):
                    ts, _ = os.path.splitext(file)
                    dt = datetime.fromtimestamp(int(ts))
                    if i == 0:
                        return f'BEFORE {dt.strftime("%Y-%m-%d")}'
                    return dt.strftime('%Y-%m-%d')

    return '????-??-?? ??:??:??'


# noinspection PyBroadException
def join_name(prev, state, k):
    try:
        prev = prev if prev is not None else ''
        if isinstance(state[k], list):
            return prev
        elif 'departmentId' in state[k]:
            return '/'.join([prev, state[k]['chineseName']])
        else:
            return '/'.join([prev, state[k]['name']])
    except Exception:
        return '/'.join([prev, '??'])


def next_pair(prev, curr, k):
    if isinstance(k, int):
        prev_next = prev[k] if k < len(prev) else None
        curr_next = curr[k] if k < len(curr) else None
    else:
        prev_next = prev[k] if k in prev else None
        curr_next = curr[k] if k in curr else None
    if prev_next is None:
        if isinstance(curr_next, dict):
            prev_next = {}
        else:
            prev_next = []
    if curr_next is None:
        if isinstance(prev_next, dict):
            curr_next = {}
        else:
            curr_next = []
    return prev_next, curr_next


def pop_path(path: str):
    return os.path.dirname(path), os.path.basename(path)


def coll_users(departments):
    users = {}

    def dfs(depart):
        nonlocal users
        for user in depart['users']:
            users[user['name']] = True
        for sub_depart in depart['subDepartments']:
            dfs(sub_depart)

    for department in departments:
        dfs(department)

    return list(users.keys())


def send_robot_message(data):
    def __send(key):
        webhook = f'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key={key}'
        print(webhook)
        r = requests.post(webhook, headers={'Content-Type': 'application/json'}, data=json.dumps(data))

        return r.json()

    # 读取环境变量（假设 WECHAT_BOT_KEY 是数组，如 ["key1", "key2"]）
    try:
        # 获取环境变量
        WECHAT_BOT_KEYS = os.environ["WECHAT_BOT_KEY"]
        
        # 尝试解析为JSON数组
        try:
            keys = json.loads(WECHAT_BOT_KEYS)
            if isinstance(keys, list):  # 确认是数组格式
                WECHAT_BOT_KEYS = keys
        except json.JSONDecodeError:
            # 不是JSON，尝试按逗号分隔处理
            if "," in WECHAT_BOT_KEYS:
                WECHAT_BOT_KEYS = [k.strip() for k in WECHAT_BOT_KEYS.split(",")]
            else:
                WECHAT_BOT_KEYS = [WECHAT_BOT_KEYS]  # 单个key转为数组
        
        # 确保最终是列表格式
        if not isinstance(WECHAT_BOT_KEYS, list):
            WECHAT_BOT_KEYS = [WECHAT_BOT_KEYS]
            
        # 发送消息
        return [__send(key) for key in WECHAT_BOT_KEYS]
    
    except KeyError:
        print("❌ 错误：未设置环境变量 WECHAT_BOT_KEY")
        raise SystemExit(1)


def send_diff_message(diff):
    curr = ''
    for line in diff:
        if len(curr + '\n' + line) < 4096:
            curr += '\n' + line
        else:
            print(send_robot_message({
                'msgtype': 'markdown',
                'markdown': {
                    'content': curr
                }
            }))
            curr = ''

    if len(curr) != 0:
        print(send_robot_message({
            'msgtype': 'markdown',
            'markdown': {
                'content': curr
            }
        }))


if __name__ == '__main__':
    if not os.path.exists('.files'):
        os.mkdir('.files')

    happens = diff_state()
    if happens:
        print(json.dumps(happens, indent=2, ensure_ascii=False))
        if os.getenv('SEND_WECOM'):
            send_diff_message(happens)
