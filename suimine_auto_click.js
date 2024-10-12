function getXPathElement(xpath) {
    return document.evaluate(xpath, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
}

function confirmAutoClick() {
    console.log('自动确认脚本开始执行!');

    const scanInterval = setInterval(() => {
        console.log("扫描确认按钮中...");

        const button = getXPathElement("//button[contains(text(), 'Mine with Web GPU')]");

        if (button && !button.disabled) {
            console.log("发现可点击按钮，正在点击...");
            button.click();
        } else {
            console.log("按钮不可用或未找到");
        }
    }, 1000);

    // 返回定时器的 ID，方便将来调用 clearInterval 停止扫描
    return scanInterval;
}

confirmAutoClick();
