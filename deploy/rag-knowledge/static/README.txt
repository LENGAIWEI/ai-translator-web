这个目录是用来「不重新打包就能改前端页面」的。

用法：
  1. 把改好的 index.html 或 eval.html 放到这个目录
  2. 浏览器 Ctrl+F5 强刷（不用重启服务）

原理：
  config/application.properties 里配置了
      spring.web.resources.static-locations=file:./static/,classpath:/static/
  优先读这个目录，找不到的文件自动回退到 jar 内置的页面。

想恢复成 jar 内置的版本：把这个目录里的文件删掉即可。

注意：这里**不放**页面的默认副本。jar 里已经内置了一份，
放副本只会导致"改了 jar 里的页面但被这里的旧副本盖住"这种迷惑情况。
