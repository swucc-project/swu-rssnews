using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class CategoryObject : ObjectType<Category>
    {
        protected override void Configure(IObjectTypeDescriptor<Category> descriptor)
        {
            descriptor.Name(nameof(Category));
            descriptor.Field(c => c.CategoryID).Type<IntType>();
            descriptor.Field(c => c.CategoryName).Type<StringType>();
        }
    }
}