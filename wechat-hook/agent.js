function _map(array, action) {
    const res = []
    for (var i = 0; i < array.count(); i++) {
        res.push(action(array.objectAtIndex_(i)))
    }
    return res
}

function toUserField(field) {
    return {
        name: field.name().toString(),
        value: field.value().toString()
    }
}

function toUser(user) {
    return {
        userId: user.userId(),
        name: user.name().toString(),
        realname: user.realName().toString(),
        mobile: user.mobile().toString(),
        title: user.externJob().toString()
    }
}

function toDepartment(department) {
    return {
        departmentId: department.departmentId(),
        chineseName: department.chineseName().toString(),
        subDepartments: [],
        users: []
    }
}

const instances = {}

function withInstance(classname, action) {
    if (!ObjC.available) return;

    if (!instances[classname]) {
        var cls = ObjC.classes[classname]
        instances[classname] = ObjC.chooseSync(cls)
    }

    if (instances[classname]) return action(instances[classname][0])
}

function withDepartmentService(action) {
    return withInstance('WEWDepartmentService', action)
}

function fetchDepartments(departmentId) {
    return withDepartmentService((service) => {
        const root = service.fetchSubDepartments_(departmentId ?? 0)
        return _map(root, toDepartment).map((department) => {
            department.subDepartments = fetchDepartments(Number(department.departmentId))
            department.users = fetchDepartmentUsers(Number(department.departmentId))

            return department
        })
    })
}

function fetchDepartmentUsers(departmentId) {
    return withDepartmentService((service) => {
        const res = service.fetchDepartmentUsers_isExternalSubDepartment_filterTagUsers_(departmentId, false, false)
        return _map(res, toUser)
    })
}

function withUserService(action) {
    return withInstance('WEWUserService', action)
}

function getUserCustomField(userId) {
    return withUserService((service) => {
        const res = service.getUserCustomField_(userId)
        return _map(res, (field) => toUserField)
    })
}

rpc.exports = {
    fetch() {
        return fetchDepartments(0)
    }
}

