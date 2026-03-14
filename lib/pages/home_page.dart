import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      body: Row(
        children: [
          // 侧边栏
          _buildSidebar(context),
          // 主内容区
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: tasksAsync.when(
                      data: (tasks) => tasks.isEmpty
                          ? _buildEmptyState(context)
                          : _buildTaskList(context, tasks, ref),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('加载失败: $e')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/upload'),
        icon: const Icon(Icons.add),
        label: const Text('新建转写'),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 200,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Logo
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.mic, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text('智能转写',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
              ],
            ),
          ),
          const Divider(),
          // 导航项
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('首页'),
            selected: true,
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('上传转写'),
            onTap: () => context.go('/upload'),
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('历史记录'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Text('智能录音转写助手',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_outlined,
              size: 120, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 24),
          Text('智能音频转文字',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 8),
          Text('支持本地识别和云端API，多渠道自动切换',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/upload'),
            icon: const Icon(Icons.upload_file),
            label: const Text('开始转写'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<Task> tasks, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          child: ListTile(
            leading: Icon(
              task.status == TaskStatus.completed
                  ? Icons.check_circle
                  : task.status == TaskStatus.running
                      ? Icons.sync
                      : Icons.schedule,
              color: task.status == TaskStatus.completed
                  ? Colors.green
                  : task.status == TaskStatus.running
                      ? Colors.blue
                      : Colors.grey,
            ),
            title: Text(task.fileName),
            subtitle: Text('${task.model} · ${task.createdAt.toString().substring(0, 16)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.status == TaskStatus.running)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: task.progress / 100,
                      strokeWidth: 3,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => context.go('/task/${task.id}'),
                ),
              ],
            ),
            onTap: () => context.go('/task/${task.id}'),
          ),
        );
      },
    );
  }
}
