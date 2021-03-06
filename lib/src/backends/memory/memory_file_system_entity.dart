part of file.src.backends.memory;

abstract class _MemoryFileSystemEntity extends FileSystemEntity {
  @override
  final MemoryFileSystem fileSystem;

  @override
  final String path;

  _MemoryFileSystemEntity(this.fileSystem, this.path);

  @override
  Future<FileSystemEntity> copy(String newPath) async {
    if (await fileSystem.type(newPath) != FileSystemEntityType.NOT_FOUND) {
      throw new FileSystemEntityException(
          'Unable to copy or move to an existing path',
          newPath);
    }
    var parent = _resolve(false);
    if (parent != null) {
      var reference = _resolve(true, newPath);
      Object clone = parent[name];
      if (clone is! String) {
        clone = _cloneSafe(clone as Map<String, Object>);
      }
      reference[newPath.substring(newPath.lastIndexOf('/') + 1)] = clone;
      if (_type == FileSystemEntityType.FILE) {
        return new _MemoryFile(fileSystem, newPath);
      } else {
        return new _MemoryDirectory(fileSystem, newPath);
      }
    }
    throw new FileSystemEntityException('Not found', path);
  }

  @override
  Future<FileSystemEntity> create({bool recursive: false}) async {
    var parent = _resolve(recursive);
    if (parent == null) {
      throw new FileSystemEntityException('Not found', getParentPath(path));
    }
    parent.putIfAbsent(name, _createImpl);
    return this;
  }

  /// Override to return a new blank object representing this entity.
  Object _createImpl();

  @override
  Future<FileSystemEntity> delete({bool recursive: false}) async {
    var parent = _resolve(recursive);
    if (parent == null) {
      throw new FileSystemEntityException('Not found', path);
    }
    if (_type == FileSystemEntityType.FILE ||
        recursive ||
        (parent[name] as Map).isEmpty) {
      parent.remove(name);
      return this;
    }
    throw new FileSystemEntityException(
        'Cannot non-recursively delete a non-empty directory',
        path);
  }

  @override
  Directory get parent {
    var parentPath = getParentPath(path);
    if (parentPath != null) {
      return new _MemoryDirectory(
          fileSystem,
          parentPath == '' ? '/' : parentPath);
    }
    return null;
  }

  // TODO: Consider promoting to FileSystemEntity.
  String get name => path.substring(path.lastIndexOf('/') + 1);

  @override
  Future<FileSystemEntity> rename(String newPath) async {
    var copied = await copy(newPath);
    await delete(recursive: true);
    return copied;
  }

  Map<String, Object> _resolve(bool recursive, [String path]) {
    path ??= this.path;
    if (path == '') {
      return fileSystem._data;
    }
    return fileSystem._resolvePath(getParentPath(path).split('/'), recursive: recursive);
  }

  /// Return what this type is.
  FileSystemEntityType get _type;
}
